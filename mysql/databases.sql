# create databases
CREATE DATABASE IF NOT EXISTS `codimd`;
CREATE USER IF NOT EXISTS 'codiuser'@'%' IDENTIFIED BY 'codipass';
GRANT ALL PRIVILEGES ON codimd.* TO 'codiuser'@'%';
