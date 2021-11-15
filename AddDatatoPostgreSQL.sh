echo "Add Data to PostgreSQL"
kubectl exec -ti my-release-postgresql-0 -n postgres-test -- bash
PGPASSWORD=${POSTGRES_PASSWORD} psql -U $POSTGRES_USER
CREATE DATABASE test;
\l
\c test
CREATE TABLE COMPANY(
     ID INT PRIMARY KEY     NOT NULL,
     NAME           TEXT    NOT NULL,
     AGE            INT     NOT NULL,
     ADDRESS        CHAR(50),
     SALARY         REAL,
     CREATED_AT    TIMESTAMP);
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY,CREATED_AT) VALUES (10, 'Paul', 32, 'California', 20000.00, now());
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY,CREATED_AT) VALUES (20, 'Omkar', 32, 'California', 20000.00, now());
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY,CREATED_AT) VALUES (30, 'Prasad', 32, 'California', 20000.00, now());
select * from company;
\q
exit