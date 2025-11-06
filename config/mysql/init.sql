CREATE DATABASE IF NOT EXISTS school_laravel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS school_ci_a CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS school_ci_b CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'school_admin'@'%' IDENTIFIED BY 'ChangeMe123!';
GRANT ALL PRIVILEGES ON school_laravel.* TO 'school_admin'@'%';
GRANT ALL PRIVILEGES ON school_ci_a.* TO 'school_admin'@'%';
GRANT ALL PRIVILEGES ON school_ci_b.* TO 'school_admin'@'%';
FLUSH PRIVILEGES;
