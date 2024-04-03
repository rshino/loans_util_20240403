/* format_v01.cpp */
/* CPP macros for formatting */

#define GET_MACRO(_0, _1, _2, NAME, ...) NAME
#define FP(...) GET_MACRO(_0, ##__VA_ARGS__, FP2, FP1, FP0)(__VA_ARGS__)
#define FC(...) GET_MACRO(_0, ##__VA_ARGS__, FC2, FC1, FC0)(__VA_ARGS__)

#ifdef HUMAN
#define FP2(x,prec) concat(format(x*100,prec),'%')
#define FP1(x) FP2(x,1)
#define FC2(x,prec) format(x,prec)
#define FC1(x) FC2(x,1)
#else
#define FP2(x,prec) round(x,prec+4)
#define FP1(x) FP2(x,1)
#define FC2(x,prec) round(x,prec+2)
#define FC1(x) FC2(x,1)
#endif
