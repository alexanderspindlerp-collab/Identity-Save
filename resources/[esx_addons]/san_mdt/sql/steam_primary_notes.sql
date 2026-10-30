-- SAN MDT Steam primary notes
-- ESX skal køre med: setr esx:identifier "steam"
-- users.identifier skal indeholde steam:xxxxxxxx, ikke license:xxxxxxxx.

-- Tjek din bruger:
SELECT identifier, firstname, lastname, job, job_grade FROM users LIMIT 20;

-- Tjek MDT employee meta matcher users.identifier:
SELECT u.identifier, u.job, m.identifier AS mdt_identifier, m.pnumber, m.division
FROM users u
LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier
LIMIT 20;
