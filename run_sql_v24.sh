#!/usr/bin/bash
# run_sql
# v22 
# v21 fixed cpp support, pass parameters to cpp via -D
# v18 added cpp
# v19 nolog
#
# parameters
#   FOO=bar
#   transforms /*_FOO_ x='_FOO_' _FOO_*/
#   into       x='bar'
#   also the equvalent of #define FOO bar
#

QUERYHISTORY=.queryhistory
echo $0 "$@" >> ${QUERYHISTORY}

if [ -n "${DEBUG}" ];
then   
    set -xv
fi
if [ -z "${TAILROWS}" ];
then
    TAILROWS=4
fi
echo


# next parameter must be the sql script
if [ -f "${1}" ]
then
    SQL="$(basename ${1} .sql )"
elif [ -f "${1}".sql ]
then
    SQL="${1}"
else
    echo "first parameter must be sql file"
    echo "neither ${$1}.sql nor ${1} found. Exiting."
    exit
fi

shift;

EGREPFILTER="([^A-Za-z0-9]_[^\t ]*_[^A-Za-z0-9]|[^A-Za-z0-9]_[^\t ]*_$)"
SEDFILTER="s|^.*[^A-Za-z0-9]_\([^\t ]*\)_.*$|\1|g"
OPTFILTERS=$(cat "${SQL}.sql" | egrep "${EGREPFILTER}" \
		 | sed -e "${SEDFILTER}" | sort -u | tr '\n' ' ')


#SCRIPT="$(basename $0)"
SCRIPT="$0"

DATESTAMP=$(date +'%Y%m%d.%H%M%S');


for PARM in $*
do
    if [[ $PARM =~ "=[" ]];  # parameter type A VAR=VAL pairs
    then
	CNT=0
	VAROOT="$(echo $PARM|cut -d= -f1)"
	for VAL in $(echo $PARM|cut -d\[ -f2 | sed -e 's/\]//' -e 's/,/ /g')
	do
	    #echo "$VAR$CNT $VAL"
	    VAR=$VAROOT$CNT
	    FILTERS+=( -e s^/\\\\*_${VAR}_^^g -e s^_${VAR}_\\\\*/^^g )
	    FILTERS+=( -e s^_${VAR}_^${VAL}^g  )
	    FILTERS+=( -e s^#${VAR}#^^g  )
	    CNT=$(($CNT+1))
	    CPPFILTERS+=( -D${VAR}=\"${VAL}\" )	    
	done
    elif [[ $PARM =~ "=" ]];  # parameter type A VAR=VAL pairs
    then
	VAR="$(echo $PARM|cut -d= -f1)"
	VAL="$(echo $PARM|cut -d= -f2)"
	FILTERS+=( -e s^/\\\\*_${VAR}_^^g -e s^_${VAR}_\\\\*/^^g )
	FILTERS+=( -e s^_${VAR}_^${VAL}^g  )
	FILTERS+=( -e s^#${VAR}#^^g  )
	CPPFILTERS+=( -D${VAR}=\"${VAL}\" )
    else
	# parameter type B tagged comment delimiters
	FILTERS+=( -e s^/\\\\*_${PARM}_^^g -e s^_${PARM}_\\\\*/^^g )
	FILTERS+=( -e s^#${PARM}#^^g  )
	CPPFILTERS+=( -D${PARM} )
    fi

    PREFIX=${PREFIX}${SEP}${PARM}
    SEP="-"
done

# put output files in _output
OUTDIRROOT='_output'
if [ ! -d ${OUTDIRROOT} ]
then
    mkdir ${OUTDIRROOT}
fi
#cd ${OUTDIRROOT}

# each run makes own subdirectory
if [ -n "${PREFIX}" ]
then
    OUT="${OUTDIRROOT}/${PREFIX}${SEP}${DATESTAMP}"
    OUTREL="${PREFIX}${SEP}${DATESTAMP}"    
    GENOUT="${OUTDIRROOT}/${PREFIX}"
else
    OUT="${OUTDIRROOT}/${SQL}${SEP}${DATESTAMP}"    
    OUTREL="${SQL}${SEP}${DATESTAMP}"    
    GENOUT="${OUTDIRROOT}/${SQL}"
fi

if [ ! -d "${OUT}" ]; then mkdir ${OUT};fi;
#ln -sf "${GENOUT}" "${OUT}"

# make backups of sh and sql
cp -p "${SCRIPT}" "${OUT}"
cp -p "${SQL}".sql "${OUT}"


if [ ${#FILTER[@]} -eq 0 ]
then
    FILTERS+=( -e s/^// )
fi

if [ -n "${DEBUG}" ]
then   
    echo "filters = " ${FILTERS[@]}
    echo "cppfilters = " ${CPPFILTERS[@]}
fi
#exit;

CMD="if [ \! -d ${OUT} ]; then mkdir ${OUT};fi;\
	cat  "${SQL}".sql \
	  | sed ${FILTERS[@]} \
	  | cpp -I. -I../00util  ${CPPFILTERS[@]} 2>/dev/null \
	  | tee "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".runlog.sql \
	  | mysql --login-path=shino loans 2>> \
	    "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log \
	  | sed -e 's/\tNULL\t/\t\t/g' -e 's/\tNULL\t/\t\t/g' \
	    -e 's/\tNULL$/\t/g' \
	  | tee "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv \
	  | tail -${TAILROWS} ;"

echo "Started ${PREFIX}${SEP}${SQL}.${DATESTAMP} at $(date)" \
    | tee -a  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;
echo "  valid SQL switches: ${OPTFILTERS}" \
    | tee -a  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;

echo "${CMD}" > "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".RUN.sh
echo "${CMD}" >>  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;
BEGINTIME="$(date +%s)"

bash -c "${CMD}" 2>&1 \
    | tee -a "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;
ERRNO=$?
ENDTIME="$(date +%s)"

ELAPSEDSEC=$(echo "scale=2;( ${ENDTIME} - ${BEGINTIME} ) " | bc  )
ELAPSEDMIN=$(echo "scale=2;( ${ENDTIME} - ${BEGINTIME} ) / 60 " | bc  )
ELAPSEDHOUR=$(echo "scale=2;( ${ENDTIME} - ${BEGINTIME} ) / 3600 " | bc  )
grep '^ERROR'  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;

echo "Elapsed ${ELAPSEDSEC} seconds = "\
     "${ELAPSEDMIN} minutes = ${ELAPSEDHOUR} hours " \
    | tee -a  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;
echo Query retcode=${ERRNO} rows=$(cat \
    "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv | wc -l ) 
echo "Completed ${PREFIX}${SEP}${SQL}"-"${DATESTAMP} at $(date)"  \
    | tee -a  "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".log;
echo;echo
if [ -n "${nolog}" ]
then
    if [ \! -d /tmp/log ] ; then mkdir /tmp/log; fi
    mv "${OUT}" /tmp/log
    ln -sf /tmp/log/"${OUT}" 00latestdir
    ln -sf /tmp/log/"${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv \
       00latest.tsv
    ln -sf /tmp/log/"${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv \    
        "${GENOUT}".tsv
else
    ln -sf "${OUT}" 00latestdir
    ln -sf "${OUT}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv 00latest.tsv
    ln -sf "${OUTREL}"/"${PREFIX}${SEP}${SQL}"-"${DATESTAMP}".tsv "${GENOUT}".tsv
fi


if [ -n "${DEBUG}" ];
then   
    set +xv
fi
