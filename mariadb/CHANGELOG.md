# Changelog for nextcloud-mariadb


## 10.5.6-2 (stable)

* Release date: 12th Oct, 2020
* Image tag: `nextcloud-proxysql/10.5.6-2`
* Improvements:
  - Updated to MariaDB 10.5.6
  - Added Adminer into the mix
* Bug fixes:
  - Dockerfile updated to 10.5.6 
* Deprecated:

## 10.5.5-1

* Release date: 9th Oct, 2020
* Image tag: `nextcloud-proxysql/10.5.5-1`
* Improvements:
  - First stable.
* Bug fixes:
* Deprecated:

## 10.5.5-0.1 (beta)

* Release date: 9th Oct, 2020
* Image tag: `nextcloud-mariadb/10.5.5-0.1`
* Improvements:
  - Added `BOOTSTRAP=1` env var
  - Added `FORCE_BOOTSTRAP=1` env var
  - Compose file example
* Bug fixes:
  - Handling the database initialization if `wsrep_on=ON`
* Deprecated:
