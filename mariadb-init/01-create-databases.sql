-- Bases de datos globales y del Lobby (Para el VPS)
CREATE DATABASE IF NOT EXISTS `authme`;
GRANT ALL PRIVILEGES ON `authme`.* TO 'minecraft'@'%';

CREATE DATABASE IF NOT EXISTS `db_fastlogin`;
GRANT ALL PRIVILEGES ON `db_fastlogin`.* TO 'minecraft'@'%';

CREATE DATABASE IF NOT EXISTS `db_minecraft`;
GRANT ALL PRIVILEGES ON `db_minecraft`.* TO 'minecraft'@'%';

CREATE DATABASE IF NOT EXISTS `db_luckperms`;
GRANT ALL PRIVILEGES ON `db_luckperms`.* TO 'minecraft'@'%';

CREATE DATABASE IF NOT EXISTS `tab`;
GRANT ALL PRIVILEGES ON `tab`.* TO 'minecraft'@'%';

FLUSH PRIVILEGES;