GRANT ALL PRIVILEGES ON *.* TO 'faindexer'@'localhost'
 IDENTIFIED BY 'r4e3w2q1' WITH GRANT OPTION;

DROP DATABASE IF EXISTS faindex;
CREATE DATABASE faindex;
USE faindex;



DROP TABLE IF EXISTS files;
CREATE TABLE files (
   id int(10) NOT NULL AUTO_INCREMENT,
   abs_path varchar(500) NOT NULL default '', 
   mtime int(10) default NULL,
   md5sum int(10) default NULL,
   PRIMARY KEY  (abs_path)
) TYPE=MyISAM;





/*
   state meaning
   1     indexing in progress, leave file alone
*/
DROP TABLE IF EXISTS state;
CREATE TABLE state (
   id int(10) NOT NULL,
   state int(2) NOT NULL, 
   PRIMARY KEY (id)
) TYPE=MyISAM;







/* 
   this is meant to index text inside the docs, not metadata
*/
DROP TABLE IF EXISTS data;
CREATE TABLE data (
   id int(10) NOT NULL,
   page_number int(10) NOT NULL,
   line_number int(10) NOT NULL,
   content text NOT NULL,
   PRIMARY KEY (id, page_number, line_number)   

) TYPE=MyISAM;
