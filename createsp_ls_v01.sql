#
delimiter //
create procedure ls()
begin
select table_schema, table_name, round((data_length)/1024/1024/1024) as 'Data (GB)',round((index_length)/1024/1024/1024) as 'Index (GB)',round((data_length+index_length)/1024/1024/1024) as 'Both (GB)' from information_schema.TABLES where table_schema=database() order by (data_length+index_length) desc;
end //
delimiter ;
