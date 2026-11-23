-- Лабораторная работа №2. Создание запросов
-- Иванова Соня, группа 25ИС2-1, вариант 11
-- Выполнять после ЛР №1 в той же базе PostgreSQL.
-- Для просмотра каждого результата выделяйте соответствующий запрос в Query Tool.

SET search_path TO sonya_v11, public;

-- 1. Все группы 1 курса математического факультета без куратора.
-- JOIN связывает группу с факультетом по его коду.
-- IS NULL проверяет отсутствие назначенного куратора.
SELECT g.*
FROM student_groups AS g
JOIN faculties AS f ON g.faculty_id = f.faculty_id
WHERE g.course = 1
  AND f.faculty_name = 'Математический факультет'
  AND g.curator_id IS NULL;

-- 2. Телефоны преподавателей, являющихся кураторами групп.
-- EXISTS проверяет, есть ли хотя бы одна группа у преподавателя.
-- Благодаря EXISTS преподаватель с несколькими группами выводится один раз.
SELECT t.teacher_id, t.last_name, t.first_name, t.phone
FROM teachers AS t
WHERE EXISTS (
    SELECT 1 FROM student_groups AS g
    WHERE g.curator_id = t.teacher_id
);

-- 3. Создаём таблицу на основе запроса 2 с номерами групп и стажем.
-- DROP удаляет только производную таблицу предыдущего запуска ЛР №2.
-- CREATE TABLE AS SELECT создаёт и сразу заполняет новую таблицу.
DROP TABLE IF EXISTS curator_report;
CREATE TABLE curator_report AS
SELECT t.teacher_id, t.last_name, t.first_name, t.phone,
       g.group_number, t.experience
FROM teachers AS t
JOIN student_groups AS g ON t.teacher_id = g.curator_id;
-- Если преподаватель курирует несколько групп, для каждой будет своя строка.
SELECT * FROM curator_report ORDER BY teacher_id, group_number;

-- 4. Добавляем преподавателей, в фамилиях которых не менее трёх гласных.
-- LOWER переводит буквы в нижний регистр.
-- REGEXP_REPLACE с флагом g удаляет все символы, кроме русских гласных.
-- CHAR_LENGTH считает оставшиеся буквы, включая повторяющиеся гласные.
-- LEFT JOIN позволяет добавить и преподавателей, у которых нет группы.
-- NOT EXISTS не даёт повторно добавить уже существующего преподавателя.
INSERT INTO curator_report
    (teacher_id, last_name, first_name, phone, group_number, experience)
SELECT t.teacher_id, t.last_name, t.first_name, t.phone,
       g.group_number, t.experience
FROM teachers AS t
LEFT JOIN student_groups AS g ON t.teacher_id = g.curator_id
WHERE CHAR_LENGTH(REGEXP_REPLACE(LOWER(t.last_name), '[^аеёиоуыэюя]', '', 'g')) >= 3
  AND NOT EXISTS (
      SELECT 1 FROM curator_report AS r WHERE r.teacher_id = t.teacher_id
  );
SELECT * FROM curator_report ORDER BY teacher_id, group_number;

-- 5. Увеличиваем стаж всех преподавателей в созданной таблице на один год.
-- UPDATE изменяет существующие строки. Без WHERE меняются все записи.
-- Исходная таблица teachers не изменяется.
UPDATE curator_report SET experience = experience + 1;
SELECT * FROM curator_report ORDER BY teacher_id, group_number;

-- 6. Удаляем кураторов со стажем меньше 10 лет из созданной таблицы.
-- В задании «классный руководитель» трактуется как куратор группы:
-- отдельного поля для классного руководителя в варианте №11 нет.
-- DELETE удаляет только строки, удовлетворяющие условию WHERE.
-- Используем стаж после увеличения на 1 год (задание 5).
DELETE FROM curator_report
WHERE group_number IS NOT NULL AND experience < 10;
SELECT * FROM curator_report ORDER BY teacher_id, group_number;

-- 7. Считаем преподавателей с высшим образованием на каждой кафедре.
-- LEFT JOIN сохраняет даже кафедры без таких преподавателей.
-- Условие образования в ON не исключает кафедры без совпадений.
-- COUNT(t.teacher_id) считает только непустые коды преподавателей.
-- GROUP BY формирует отдельную группу строк для каждой кафедры.
SELECT d.department_id, d.department_name,
       COUNT(t.teacher_id) AS teachers_with_higher_education
FROM departments AS d
LEFT JOIN teachers AS t
    ON t.department_id = d.department_id AND t.education = 'Высшее'
GROUP BY d.department_id, d.department_name
ORDER BY d.department_id;
