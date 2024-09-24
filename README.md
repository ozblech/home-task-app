## Overview
This application was created by develeap for learning purposes in practicing different tools and technolegies. 

# WorkProfile Application Project
WorkProfile is a basic program that lists people's work information.

# Database
This application depends on a MySQL database in order to unlock full functionality.
It can be deployed standalone or with a database. If deployed without a database, it will provide a read-only version with an example database and no ability to modify its contents. If a database is properly attached, it will allow the user to add and delete entries.

## Requirements

In order to run this application, you need Python 3.10 installed. Depending on your environment, you may also need to install certain packages to your OS:

* `pkg-config`
* `libmysqlclient-dev`
* `python3.10-dev`
* `build-essential`

# Python Virtual Environment
It's a best practice to run Python applications in a venv. Make sure you have python3.10-venv installed. If not, you can install it with the following command: `sudo apt install python3.10-venv`.
For more information about venv go to https://docs.python.org/3/library/venv.html#module-venv.


## Instructions
1) Create a venv: `python3.10 -m venv venv`
2) Activate it: `source venv/bin/activate`
3) Install the requirements: `pip install -r requirements.txt`
4) run the application: `gunicorn --workers 4 --bind 0.0.0.0:8080 --access-logfile - --error-logfile - app:app`

## Environment Variables

The following environment variables are required when deploying the application with a database:

- `DB_HOST`: The database connection string path.
- `BACKEND`: The URI to this application (<http://localhost> if deployed locally, a DNS/IP otherwise).
- `DB_USER`: The database user. Must match the user in the SQL dump and `MYSQL_USER`.
- `DB_PASS`: The user password. Must match `MYSQL_PASSWORD`.
- `DB_NAME`: The database name. Must match `MYSQL_DATABASE` as well as the database name in the SQL dump.