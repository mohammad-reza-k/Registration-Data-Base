CREATE FUNCTION public.check_prerequisite(stuid integer, offerid integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

declare
	prere_cursor cursor for
		select p.pre_id, p.pre_type
		from prerequisite p
		join course_offering co on co.c_id = p.c_id
		where co.offering_id = offerid;
	prere_record RECORD;
	obtained_score numeric(4,2);
begin
	open prere_cursor;
	loop
		fetch prere_cursor into prere_record;
		exit when not found;

		select g.numeric_grade into obtained_score
		from grade g join enrollment e on g.enroll_id = e.enrollment_id and g.grade_type = 'نهایی'
		join course_offering co on co.offering_id = e.offer_id
		WHERE e.stu_id = stuid and co.c_id = prere_record.pre_id and e.status = 'ثبت نام نهایی';

		if obtained_score is null or obtained_score < 10.00 then
            close prere_cursor;
            return FALSE;
        end if;
    end loop;
	close prere_cursor;
    return TRUE;
end;
$$;

CREATE FUNCTION public.check_max_units() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_units INTEGER;
    max_units INTEGER := 20; 
BEGIN
    SELECT SUM(c.credits) INTO total_units
    FROM enrollment e
    JOIN course_offering co ON co.offering_id = e.offer_id
    JOIN course c ON c.course_id = co.c_id
    WHERE e.stu_id = NEW.stu_id
    AND e.status IN ('ثبت نام نهایی', 'ثبت نام موقت');
    
    IF total_units + (SELECT credits FROM course c 
                      JOIN course_offering co ON co.c_id = c.course_id 
                      WHERE co.offering_id = NEW.offer_id) > max_units THEN
        RAISE EXCEPTION 'تعداد واحدهای انتخاب شده بیش از حد مجاز است';
    END IF;
    
    RETURN NEW;
END;
$$;
CREATE FUNCTION public.insert_last_grade(stid integer, offerid integer) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
DECLARE
    avg_grade float;
	enrollid integer;
	profid integer;
BEGIN
	select g.prof_id into profid
	from grade g
	join enrollment e on g.enroll_id = e.enrollment_id 
	where e.stu_id = stid and e.offer_id = offerid
	limit 1;

	select g.enroll_id into enrollid
	from grade g
    JOIN enrollment e ON g.enroll_id = e.enrollment_id
    WHERE e.stu_id = stid and e.offer_id = offerid
	limit 1;
	
	SELECT ROUND(AVG(g.numeric_grade), 2) 
    INTO avg_grade
    FROM grade g 
    JOIN enrollment e ON g.enroll_id = e.enrollment_id
    WHERE e.stu_id = stid and e.offer_id = offerid
	GROUP BY g.enroll_id;
	
	INSERT INTO grade (grade_type, numeric_grade, letter_grade, grade_date, prof_id, enroll_id) VALUES
	('نهایی', avg_grade , '', current_date ,profid, enrollid);
    
    
    RETURN avg_grade;
END;
$$;


CREATE FUNCTION public.calculate_last_grade(stid integer, offerid integer) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
DECLARE
    avg_grade float;
BEGIN
    SELECT ROUND(AVG(g.numeric_grade), 2) 
    INTO avg_grade
    FROM grade g 
    JOIN enrollment e ON g.enroll_id = e.enrollment_id
    WHERE e.stu_id = stid and e.offer_id = offerid
	GROUP BY g.enroll_id;
    
    RETURN avg_grade;
END;
$$;


ALTER FUNCTION public.calculate_last_grade(stid integer, offerid integer) OWNER TO postgres;

