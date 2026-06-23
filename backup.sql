--
-- PostgreSQL database dump
--

\restrict NhMeeOBg8H2IqcSU5KbtnESlL3vVfnRtKQVKgrPgK4shQ93iG461ENwLLzmyjNc

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-06-13 15:37:52

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 18482)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 285 (class 1255 OID 21422)
-- Name: calculate_last_grade(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

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

--
-- TOC entry 297 (class 1255 OID 21424)
-- Name: check_max_units(); Type: FUNCTION; Schema: public; Owner: postgres
--

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


ALTER FUNCTION public.check_max_units() OWNER TO postgres;

--
-- TOC entry 299 (class 1255 OID 21426)
-- Name: check_prerequisite(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

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


ALTER FUNCTION public.check_prerequisite(stuid integer, offerid integer) OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 21423)
-- Name: insert_last_grade(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

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


ALTER FUNCTION public.insert_last_grade(stid integer, offerid integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 241 (class 1259 OID 17997)
-- Name: class_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class_schedule (
    class_schedule_id integer NOT NULL,
    room_number integer,
    start_time time without time zone,
    end_time time without time zone,
    day_of_week character varying(20),
    offer_id integer NOT NULL,
    dep_id integer NOT NULL,
    CONSTRAINT class_schedule_check CHECK ((start_time < end_time)),
    CONSTRAINT class_schedule_check1 CHECK (((end_time - start_time) = '02:00:00'::interval)),
    CONSTRAINT class_schedule_day_of_week_check CHECK (((day_of_week)::text = ANY ((ARRAY['شنبه'::character varying, 'یکشنبه'::character varying, 'دوشنبه'::character varying, 'سه شنبه'::character varying, 'چهارشنبه'::character varying, 'پنجشنبه'::character varying, 'جمعه'::character varying])::text[])))
);


ALTER TABLE public.class_schedule OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17996)
-- Name: class_schedule_class_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.class_schedule_class_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.class_schedule_class_schedule_id_seq OWNER TO postgres;

--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 240
-- Name: class_schedule_class_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.class_schedule_class_schedule_id_seq OWNED BY public.class_schedule.class_schedule_id;


--
-- TOC entry 234 (class 1259 OID 17904)
-- Name: course; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course (
    course_id integer NOT NULL,
    course_code character varying(20) NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    course_type character varying(20) NOT NULL,
    credits integer NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    dep_id integer NOT NULL,
    CONSTRAINT course_course_type_check CHECK (((course_type)::text = ANY ((ARRAY['پایه'::character varying, 'تخصصی'::character varying, 'اختیاری'::character varying, 'عمومی'::character varying, 'نظری'::character varying, 'عملی'::character varying])::text[]))),
    CONSTRAINT course_credits_check CHECK (((credits >= 0) AND (credits <= 4)))
);


ALTER TABLE public.course OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 17903)
-- Name: course_course_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_course_id_seq OWNER TO postgres;

--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 233
-- Name: course_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_course_id_seq OWNED BY public.course.course_id;


--
-- TOC entry 239 (class 1259 OID 17964)
-- Name: course_offering; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.course_offering (
    offering_id integer NOT NULL,
    status character varying(20) NOT NULL,
    capacity integer DEFAULT 0,
    registered_count integer DEFAULT 0,
    c_id integer NOT NULL,
    prof_id integer NOT NULL,
    sem_id integer NOT NULL,
    CONSTRAINT course_offering_check CHECK ((registered_count <= capacity)),
    CONSTRAINT course_offering_status_check CHECK (((status)::text = ANY ((ARRAY['غیر قابل اخذ'::character varying, 'قابل اخذ'::character varying])::text[])))
);


ALTER TABLE public.course_offering OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17963)
-- Name: course_offering_offering_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.course_offering_offering_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_offering_offering_id_seq OWNER TO postgres;

--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 238
-- Name: course_offering_offering_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.course_offering_offering_id_seq OWNED BY public.course_offering.offering_id;


--
-- TOC entry 221 (class 1259 OID 17770)
-- Name: department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department (
    department_id integer NOT NULL,
    department_name character varying(50) NOT NULL,
    faculty_name character varying(50)
);


ALTER TABLE public.department OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17769)
-- Name: department_department_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.department_department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.department_department_id_seq OWNER TO postgres;

--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 220
-- Name: department_department_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.department_department_id_seq OWNED BY public.department.department_id;


--
-- TOC entry 222 (class 1259 OID 17782)
-- Name: department_phone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department_phone (
    dep_id integer NOT NULL,
    phone_number character varying(11) NOT NULL
);


ALTER TABLE public.department_phone OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 18046)
-- Name: enrollment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enrollment (
    enrollment_id integer NOT NULL,
    enrollment_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(20),
    offer_id integer NOT NULL,
    stu_id integer NOT NULL,
    CONSTRAINT enrollment_status_check CHECK (((status)::text = ANY ((ARRAY['قبول'::character varying, 'رد'::character varying, 'ثبت نام نهایی'::character varying, 'ثبت نام موقت'::character varying, 'حذف اضطراری'::character varying])::text[])))
);


ALTER TABLE public.enrollment OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 18045)
-- Name: enrollment_enrollment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.enrollment_enrollment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.enrollment_enrollment_id_seq OWNER TO postgres;

--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 244
-- Name: enrollment_enrollment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.enrollment_enrollment_id_seq OWNED BY public.enrollment.enrollment_id;


--
-- TOC entry 243 (class 1259 OID 18022)
-- Name: exam_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exam_schedule (
    exam_schedule_id integer NOT NULL,
    room_number integer,
    start_time time without time zone,
    end_time time without time zone,
    exam_date date,
    offer_id integer NOT NULL,
    dep_id integer NOT NULL,
    CONSTRAINT exam_schedule_check CHECK ((start_time < end_time)),
    CONSTRAINT exam_schedule_check1 CHECK (((end_time - start_time) = '02:00:00'::interval))
);


ALTER TABLE public.exam_schedule OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 18021)
-- Name: exam_schedule_exam_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.exam_schedule_exam_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.exam_schedule_exam_schedule_id_seq OWNER TO postgres;

--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 242
-- Name: exam_schedule_exam_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.exam_schedule_exam_schedule_id_seq OWNED BY public.exam_schedule.exam_schedule_id;


--
-- TOC entry 247 (class 1259 OID 18070)
-- Name: grade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grade (
    grade_id integer NOT NULL,
    grade_type character varying(30) NOT NULL,
    numeric_grade numeric(4,2),
    letter_grade character varying(50),
    grade_date date DEFAULT CURRENT_DATE,
    prof_id integer NOT NULL,
    enroll_id integer NOT NULL,
    CONSTRAINT grade_grade_type_check CHECK (((grade_type)::text = ANY ((ARRAY['نهایی'::character varying, 'میان ترم'::character varying, 'پایان ترم'::character varying, 'تمرین'::character varying, 'پروژه'::character varying, 'کوئیز'::character varying])::text[]))),
    CONSTRAINT grade_numeric_grade_check CHECK (((numeric_grade >= 0.00) AND (numeric_grade <= 20.00)))
);


ALTER TABLE public.grade OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 18069)
-- Name: grade_grade_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grade_grade_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.grade_grade_id_seq OWNER TO postgres;

--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 246
-- Name: grade_grade_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.grade_grade_id_seq OWNED BY public.grade.grade_id;


--
-- TOC entry 235 (class 1259 OID 17929)
-- Name: prerequisite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prerequisite (
    c_id integer NOT NULL,
    pre_id integer NOT NULL,
    min_grade numeric(4,2) DEFAULT 10.00,
    pre_type character varying(20),
    CONSTRAINT prerequisite_pre_type_check CHECK (((pre_type)::text = ANY ((ARRAY['پیش نیاز'::character varying, 'هم نیاز'::character varying])::text[])))
);


ALTER TABLE public.prerequisite OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17852)
-- Name: professor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.professor (
    professor_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    gender character varying(20) NOT NULL,
    academic_rank character varying(20),
    national_code character varying(10) NOT NULL,
    date_of_birth date,
    password character varying(255) NOT NULL,
    dep_id integer NOT NULL,
    CONSTRAINT professor_academic_rank_check CHECK (((academic_rank)::text = ANY ((ARRAY['استاد یار'::character varying, 'استاد'::character varying, 'دانشیار'::character varying, 'مربی'::character varying])::text[])))
);


ALTER TABLE public.professor OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17888)
-- Name: professor_email; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.professor_email (
    email_id integer NOT NULL,
    prof_id integer NOT NULL,
    email character varying(255)
);


ALTER TABLE public.professor_email OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17887)
-- Name: professor_email_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.professor_email_email_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.professor_email_email_id_seq OWNER TO postgres;

--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 231
-- Name: professor_email_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.professor_email_email_id_seq OWNED BY public.professor_email.email_id;


--
-- TOC entry 230 (class 1259 OID 17873)
-- Name: professor_phone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.professor_phone (
    prof_id integer NOT NULL,
    phone_number character varying(11) NOT NULL
);


ALTER TABLE public.professor_phone OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17851)
-- Name: professor_professor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.professor_professor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.professor_professor_id_seq OWNER TO postgres;

--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 228
-- Name: professor_professor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.professor_professor_id_seq OWNED BY public.professor.professor_id;


--
-- TOC entry 237 (class 1259 OID 17949)
-- Name: semester; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.semester (
    semester_id integer NOT NULL,
    term_name character varying(20) NOT NULL,
    start_date date,
    end_date date,
    registration_start_date date,
    registration_end_date date,
    is_active boolean DEFAULT false NOT NULL,
    CONSTRAINT semester_check CHECK ((start_date < end_date)),
    CONSTRAINT semester_check1 CHECK ((registration_start_date < registration_end_date))
);


ALTER TABLE public.semester OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17948)
-- Name: semester_semester_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.semester_semester_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.semester_semester_id_seq OWNER TO postgres;

--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 236
-- Name: semester_semester_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.semester_semester_id_seq OWNED BY public.semester.semester_id;


--
-- TOC entry 224 (class 1259 OID 17797)
-- Name: student; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student (
    student_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    gender character varying(20) NOT NULL,
    student_number character varying(10) NOT NULL,
    national_code character varying(10) NOT NULL,
    date_of_birth date,
    entry_year integer,
    password character varying(255) NOT NULL,
    dep_id integer NOT NULL,
    CONSTRAINT student_entry_year_check CHECK ((entry_year >= 1398))
);


ALTER TABLE public.student OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17836)
-- Name: student_email; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_email (
    email_id integer NOT NULL,
    stu_id integer NOT NULL,
    email character varying(255)
);


ALTER TABLE public.student_email OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17835)
-- Name: student_email_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.student_email_email_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.student_email_email_id_seq OWNER TO postgres;

--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 226
-- Name: student_email_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.student_email_email_id_seq OWNED BY public.student_email.email_id;


--
-- TOC entry 225 (class 1259 OID 17821)
-- Name: student_phone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_phone (
    stu_id integer NOT NULL,
    phone_number character varying(11) NOT NULL
);


ALTER TABLE public.student_phone OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17796)
-- Name: student_student_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.student_student_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.student_student_id_seq OWNER TO postgres;

--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 223
-- Name: student_student_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.student_student_id_seq OWNED BY public.student.student_id;


--
-- TOC entry 4982 (class 2604 OID 18000)
-- Name: class_schedule class_schedule_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_schedule ALTER COLUMN class_schedule_id SET DEFAULT nextval('public.class_schedule_class_schedule_id_seq'::regclass);


--
-- TOC entry 4974 (class 2604 OID 17907)
-- Name: course course_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course ALTER COLUMN course_id SET DEFAULT nextval('public.course_course_id_seq'::regclass);


--
-- TOC entry 4979 (class 2604 OID 17967)
-- Name: course_offering offering_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering ALTER COLUMN offering_id SET DEFAULT nextval('public.course_offering_offering_id_seq'::regclass);


--
-- TOC entry 4969 (class 2604 OID 17773)
-- Name: department department_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department ALTER COLUMN department_id SET DEFAULT nextval('public.department_department_id_seq'::regclass);


--
-- TOC entry 4984 (class 2604 OID 18049)
-- Name: enrollment enrollment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enrollment ALTER COLUMN enrollment_id SET DEFAULT nextval('public.enrollment_enrollment_id_seq'::regclass);


--
-- TOC entry 4983 (class 2604 OID 18025)
-- Name: exam_schedule exam_schedule_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam_schedule ALTER COLUMN exam_schedule_id SET DEFAULT nextval('public.exam_schedule_exam_schedule_id_seq'::regclass);


--
-- TOC entry 4986 (class 2604 OID 18073)
-- Name: grade grade_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grade ALTER COLUMN grade_id SET DEFAULT nextval('public.grade_grade_id_seq'::regclass);


--
-- TOC entry 4972 (class 2604 OID 17855)
-- Name: professor professor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor ALTER COLUMN professor_id SET DEFAULT nextval('public.professor_professor_id_seq'::regclass);


--
-- TOC entry 4973 (class 2604 OID 17891)
-- Name: professor_email email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_email ALTER COLUMN email_id SET DEFAULT nextval('public.professor_email_email_id_seq'::regclass);


--
-- TOC entry 4977 (class 2604 OID 17952)
-- Name: semester semester_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.semester ALTER COLUMN semester_id SET DEFAULT nextval('public.semester_semester_id_seq'::regclass);


--
-- TOC entry 4970 (class 2604 OID 17800)
-- Name: student student_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student ALTER COLUMN student_id SET DEFAULT nextval('public.student_student_id_seq'::regclass);


--
-- TOC entry 4971 (class 2604 OID 17839)
-- Name: student_email email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_email ALTER COLUMN email_id SET DEFAULT nextval('public.student_email_email_id_seq'::regclass);


--
-- TOC entry 5260 (class 0 OID 17997)
-- Dependencies: 241
-- Data for Name: class_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.class_schedule (class_schedule_id, room_number, start_time, end_time, day_of_week, offer_id, dep_id) FROM stdin;
1	101	08:00:00	10:00:00	شنبه	1	1
2	101	08:00:00	10:00:00	یکشنبه	1	1
3	102	10:00:00	12:00:00	شنبه	2	1
4	102	10:00:00	12:00:00	دوشنبه	2	1
5	201	13:00:00	15:00:00	شنبه	3	1
6	201	13:00:00	15:00:00	سه شنبه	3	1
7	301	08:00:00	10:00:00	یکشنبه	4	2
8	302	10:00:00	12:00:00	دوشنبه	5	2
9	401	13:00:00	15:00:00	سه شنبه	6	3
10	402	15:00:00	17:00:00	چهارشنبه	7	3
\.


--
-- TOC entry 5253 (class 0 OID 17904)
-- Dependencies: 234
-- Data for Name: course; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course (course_id, course_code, name, description, course_type, credits, is_active, dep_id) FROM stdin;
1	CS101	مبانی کامپیوتر و برنامه‌سازی	آشنایی با مفاهیم پایه کامپیوتر و الگوریتم	تخصصی	3	t	1
2	CS201	ساختمان داده‌ها	آشنایی با ساختارهای داده پایه و پیشرفته	تخصصی	3	t	1
3	CS301	طراحی الگوریتم‌ها	روش‌های طراحی و تحلیل الگوریتم	تخصصی	3	t	1
4	EE101	مدارهای الکتریکی ۱	آشنایی با مفاهیم پایه مدارهای الکتریکی	تخصصی	3	t	2
5	EE201	الکترونیک ۱	آشنایی با قطعات الکترونیکی و مدارات	تخصصی	3	t	2
6	ME101	استاتیک	آشنایی با تعادل اجسام صلب	تخصصی	3	t	3
7	ME201	دینامیک	آشنایی با حرکت اجسام و نیروها	تخصصی	3	t	3
8	MATH101	ریاضی عمومی ۱	مفاهیم پایه ریاضی شامل حد، مشتق، انتگرال	پایه	3	t	5
9	PHY101	فیزیک عمومی ۱	مکانیک کلاسیک و ترمودینامیک	پایه	3	t	6
10	MGT101	مبانی مدیریت	آشنایی با اصول و مبانی مدیریت	عمومی	2	t	8
\.


--
-- TOC entry 5258 (class 0 OID 17964)
-- Dependencies: 239
-- Data for Name: course_offering; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.course_offering (offering_id, status, capacity, registered_count, c_id, prof_id, sem_id) FROM stdin;
1	قابل اخذ	35	0	1	1	2
2	قابل اخذ	30	0	2	1	2
3	قابل اخذ	40	0	3	2	2
4	قابل اخذ	25	0	4	3	2
5	قابل اخذ	30	0	5	4	2
6	قابل اخذ	20	0	6	5	2
7	غیر قابل اخذ	30	0	7	6	2
8	قابل اخذ	50	0	8	9	2
9	قابل اخذ	45	0	9	10	2
10	قابل اخذ	35	0	10	7	2
\.


--
-- TOC entry 5240 (class 0 OID 17770)
-- Dependencies: 221
-- Data for Name: department; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.department (department_id, department_name, faculty_name) FROM stdin;
1	مهندسی کامپیوتر	دانشکده فنی و مهندسی
2	مهندسی برق	دانشکده فنی و مهندسی
3	مهندسی مکانیک	دانشکده فنی و مهندسی
4	علوم کامپیوتر	دانشکده علوم پایه
5	ریاضی	دانشکده علوم پایه
6	فیزیک	دانشکده علوم پایه
7	شیمی	دانشکده علوم پایه
8	مدیریت بازرگانی	دانشکده مدیریت
9	حسابداری	دانشکده مدیریت
10	حقوق	دانشکده علوم انسانی
\.


--
-- TOC entry 5241 (class 0 OID 17782)
-- Dependencies: 222
-- Data for Name: department_phone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.department_phone (dep_id, phone_number) FROM stdin;
1	02166123456
1	02166123457
2	02166123458
3	02166123459
4	02166123460
5	02166123461
6	02166123462
7	02166123463
8	02166123464
9	02166123465
\.


--
-- TOC entry 5264 (class 0 OID 18046)
-- Dependencies: 245
-- Data for Name: enrollment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.enrollment (enrollment_id, enrollment_date, status, offer_id, stu_id) FROM stdin;
1	1403-11-10 10:30:00	ثبت نام نهایی	1	1
2	1403-11-10 11:00:00	ثبت نام نهایی	2	1
3	1403-11-11 09:15:00	ثبت نام نهایی	1	2
4	1403-11-11 10:00:00	ثبت نام نهایی	3	2
5	1403-11-12 14:30:00	ثبت نام نهایی	4	3
6	1403-11-12 15:00:00	ثبت نام نهایی	5	3
7	1403-11-13 08:45:00	ثبت نام موقت	6	4
8	1403-11-13 09:30:00	ثبت نام موقت	8	5
9	1403-11-14 11:20:00	ثبت نام موقت	9	6
10	1403-11-14 12:00:00	ثبت نام نهایی	10	7
11	1403-11-10 10:30:00	ثبت نام نهایی	1	3
12	1403-11-13 08:45:00	ثبت نام نهایی	5	4
16	1403-11-10 10:30:00	ثبت نام نهایی	3	1
17	1403-11-10 10:30:00	ثبت نام نهایی	4	1
18	1403-11-10 10:30:00	ثبت نام نهایی	5	1
19	1403-11-10 10:30:00	ثبت نام نهایی	6	1
\.


--
-- TOC entry 5262 (class 0 OID 18022)
-- Dependencies: 243
-- Data for Name: exam_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.exam_schedule (exam_schedule_id, room_number, start_time, end_time, exam_date, offer_id, dep_id) FROM stdin;
1	101	08:00:00	10:00:00	1403-12-10	1	1
2	102	10:00:00	12:00:00	1403-12-12	2	1
3	201	13:00:00	15:00:00	1403-12-15	3	1
4	301	08:00:00	10:00:00	1403-12-18	4	2
5	302	10:00:00	12:00:00	1403-12-20	5	2
6	401	13:00:00	15:00:00	1403-12-22	6	3
7	402	15:00:00	17:00:00	1403-12-25	7	3
8	101	08:00:00	10:00:00	1403-12-28	8	1
9	102	10:00:00	12:00:00	1403-12-30	9	1
10	201	13:00:00	15:00:00	1404-01-05	10	8
\.


--
-- TOC entry 5266 (class 0 OID 18070)
-- Dependencies: 247
-- Data for Name: grade; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.grade (grade_id, grade_type, numeric_grade, letter_grade, grade_date, prof_id, enroll_id) FROM stdin;
1	نهایی	18.50	هجده و نیم	1403-12-20	1	1
2	میان ترم	16.00	شانزده	1403-11-20	1	1
3	نهایی	17.00	هفده	1403-12-20	1	2
4	تمرین	19.00	نوزده	1403-11-25	1	2
5	نهایی	14.50	چهارده و نیم	1403-12-20	2	3
6	پروژه	18.00	هجده	1403-12-01	2	4
7	نهایی	19.50	نوزده و نیم	1403-12-22	3	5
8	کوئیز	15.00	پانزده	1403-11-30	4	6
9	نهایی	12.00	دوازده	1403-12-25	5	7
10	میان ترم	17.50	هفده و نیم	1403-11-15	6	8
11	پایان ترم	12.00		1403-12-20	1	11
12	میان ترم	13.00		1403-11-20	1	11
13	پروژه	13.75		1403-12-20	1	11
14	تمرین	16.50		1403-11-25	1	11
15	نهایی	13.81		2026-06-10	1	11
17	نهایی	12.00		1403-12-20	1	12
\.


--
-- TOC entry 5254 (class 0 OID 17929)
-- Dependencies: 235
-- Data for Name: prerequisite; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prerequisite (c_id, pre_id, min_grade, pre_type) FROM stdin;
2	1	10.00	پیش نیاز
6	5	10.00	پیش نیاز
\.


--
-- TOC entry 5248 (class 0 OID 17852)
-- Dependencies: 229
-- Data for Name: professor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.professor (professor_id, first_name, last_name, gender, academic_rank, national_code, date_of_birth, password, dep_id) FROM stdin;
1	دکتر احمد	پرویزی	مرد	استاد	1012345678	1350-03-15	$2a$06$b2qGm4wJmfiAkLfdsMVuxeJuQoHC1B2O1WHvIaxinWSmArTA3zd9W	1
2	دکتر مریم	حیدری	زن	دانشیار	1012345679	1355-07-20	$2a$06$1ySmOfDAFRZ9GweD/5WrJe.Kv40dV2rp.fmzf7DX1q3SByCdC/r4W	1
3	دکتر رضا	کریمیان	مرد	استاد یار	1012345680	1360-11-10	$2a$06$1TRM.ve7UguW2fxf8seyMOti5mN0hLkSpIlm/SZXyWF5r5S7N4Iiy	2
4	دکتر ناهید	شفیعی	زن	استاد	1012345681	1352-05-25	$2a$06$rq1MFoDWct9yDETCjDFyfOxDaED1XdsYGosQfNHbEqWWnz2kXpzLm	2
5	دکتر عباس	نظری	مرد	دانشیار	1012345682	1358-09-05	$2a$06$BowVOnZvcnaHgreDvSfNgOgN7WQG7KWS5qprlI.t3V4pER7HT3da2	3
6	دکتر سیمین	بهبهانی	زن	مربی	1012345683	1365-12-12	$2a$06$dwz42.nJd6fzoZZmb9b4hOjG4JvirAhzKx1qBXV.goQlARoOwPVbW	3
7	دکتر محمود	طاهری	مرد	استاد یار	1012345684	1362-02-18	$2a$06$ixu8M3TJoncmmIKV7mcDueDik96jW7pwG/QSmyX79oaeMeXLfJf0K	4
8	دکتر الهه	میرزایی	زن	دانشیار	1012345685	1357-04-22	$2a$06$p.NWOhBEbJzNTsdeS0CfYej6zFerqJ/wxCCXgyMWPydNRphPS8vd2	4
9	دکتر حسن	فرهادی	مرد	استاد	1012345686	1350-08-30	$2a$06$5gWNpqG37uuGumkB.QPUfun.EdunBP0gwO9cD60SKF9Zh/ZulQJmi	5
10	دکتر فریبا	کمانگر	زن	استاد یار	1012345687	1363-10-14	$2a$06$OeWLMi8VTWq8PxwbO9Vv6ec0mjk2.qs6kxeifVuAZ3d58Z.3Nn1c2	6
\.


--
-- TOC entry 5251 (class 0 OID 17888)
-- Dependencies: 232
-- Data for Name: professor_email; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.professor_email (email_id, prof_id, email) FROM stdin;
1	1	ahmad.provizi@university.edu
2	1	a.provizi@university.edu
3	2	maryam.heydari@university.edu
4	3	reza.karimian@university.edu
5	4	nahid.shabei@university.edu
6	5	abbas.nazari@university.edu
7	6	simin.behbahani@university.edu
8	7	mahmoud.taheri@university.edu
9	8	elahe.mirzaei@university.edu
10	9	hassan.farhadi@university.edu
\.


--
-- TOC entry 5249 (class 0 OID 17873)
-- Dependencies: 230
-- Data for Name: professor_phone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.professor_phone (prof_id, phone_number) FROM stdin;
1	09131111111
1	09131111112
2	09132222222
3	09133333333
4	09134444444
5	09135555555
6	09136666666
7	09137777777
8	09138888888
9	09139999999
\.


--
-- TOC entry 5256 (class 0 OID 17949)
-- Dependencies: 237
-- Data for Name: semester; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.semester (semester_id, term_name, start_date, end_date, registration_start_date, registration_end_date, is_active) FROM stdin;
1	نیمسال اول ۱۴۰۳-۱۴۰۴	1403-07-01	1403-11-15	1403-06-15	1403-06-30	f
2	نیمسال دوم ۱۴۰۳-۱۴۰۴	1403-11-20	1404-03-15	1403-11-01	1403-11-15	t
3	تابستان ۱۴۰۴	1404-04-01	1404-06-30	1404-03-15	1404-03-30	f
4	نیمسال اول ۱۴۰۲-۱۴۰۳	1402-07-01	1402-11-15	1402-06-15	1402-06-30	f
5	نیمسال دوم ۱۴۰۲-۱۴۰۳	1402-11-20	1403-03-15	1402-11-01	1402-11-15	f
6	تابستان ۱۴۰۳	1403-04-01	1403-06-30	1403-03-15	1403-03-30	f
7	نیمسال اول ۱۴۰۱-۱۴۰۲	1401-07-01	1401-11-15	1401-06-15	1401-06-30	f
8	نیمسال دوم ۱۴۰۱-۱۴۰۲	1401-11-20	1402-03-15	1401-11-01	1401-11-15	f
9	نیمسال اول ۱۴۰۴-۱۴۰۵	1404-07-01	1404-11-15	1404-06-15	1404-06-30	f
10	نیمسال دوم ۱۴۰۴-۱۴۰۵	1404-11-20	1405-03-15	1404-11-01	1404-11-15	f
\.


--
-- TOC entry 5243 (class 0 OID 17797)
-- Dependencies: 224
-- Data for Name: student; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student (student_id, first_name, last_name, gender, student_number, national_code, date_of_birth, entry_year, password, dep_id) FROM stdin;
1	علی	رضایی	مرد	4011011001	0012345678	1385-03-15	1401	$2a$06$iV7FdCKoQ.b2amlraGuVyudFVAS4lcE2wL7iFy70EIlAmNCeHZBsK	1
2	سارا	کریمی	زن	4011011002	0012345679	1385-05-20	1401	$2a$06$O2u9GsDqoxUSqn9k8/bi2eIj3XJahwflrtvXbKQgVQwc2MoJj8XoS	1
3	محمد	نوری	مرد	4021012001	0012345680	1386-07-10	1402	$2a$06$3tVaCzNYJV29xkfmsWLMsuad3datAHte7Aru4OCQLvvbPRoOeGrQ6	2
4	زهرا	احمدی	زن	4021012002	0012345681	1386-09-25	1402	$2a$06$41HLskD7Yq8g4dDnMwCUsuR0HXGe.eKzVubvEkzErJIsHiQSS5XwC	2
5	رضا	محمدی	مرد	4031013001	0012345682	1387-11-05	1403	$2a$06$cRVzdxKAHX0/HzEfJMOoseC1KBgzK7JxJqP6nyNtBIMtaL5ZrubJy	3
6	نرگس	حسینی	زن	4031013002	0012345683	1387-12-12	1403	$2a$06$ZpxPXG3iCRqQDApRmX4es.uAScNTFtJ5o7d1CbZ0CZTwkahxC.pwS	3
7	امیر	قاسمی	مرد	4011044001	0012345684	1385-02-18	1401	$2a$06$tL/jQEL83tz3BYjK0Unwy.VXz33vUY2YjOn.p1qBx34rf5dg4QMH2	4
8	فاطمه	کاظمی	زن	4021044002	0012345685	1386-04-22	1402	$2a$06$s8FuIkZsVrqB67OwldROeOlOsHhgVrihyghr3QI9WCmkFudwuOOMC	4
9	حسین	موسوی	مرد	4031055001	0012345686	1387-08-30	1403	$2a$06$cXjeFPR9PucAgjgFU5nXa.b.40TRpY11vsjIcH2HnkbriewgMJFVS	5
10	لیلا	رضوی	زن	4011066001	0012345687	1385-10-14	1401	$2a$06$0qeIn9ujDWUIlVP71egVyugGWmNmFCdZbHtZPp8LSEdGzop636QNW	6
\.


--
-- TOC entry 5246 (class 0 OID 17836)
-- Dependencies: 227
-- Data for Name: student_email; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_email (email_id, stu_id, email) FROM stdin;
1	1	ali.rezaei@university.edu
2	1	ali.rezaei2@university.edu
3	2	sara.karimi@university.edu
4	3	mohammad.nouri@university.edu
5	4	zahra.ahmadi@university.edu
6	5	reza.mohammadi@university.edu
7	6	narges.hosseini@university.edu
8	7	amir.ghasemi@university.edu
9	8	fatemeh.kazemi@university.edu
10	9	hossein.mousavi@university.edu
\.


--
-- TOC entry 5244 (class 0 OID 17821)
-- Dependencies: 225
-- Data for Name: student_phone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_phone (stu_id, phone_number) FROM stdin;
1	09121111111
1	09121111112
2	09122222222
3	09123333333
4	09124444444
5	09125555555
6	09126666666
7	09127777777
8	09128888888
9	09129999999
\.


--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 240
-- Name: class_schedule_class_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.class_schedule_class_schedule_id_seq', 10, true);


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 233
-- Name: course_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_course_id_seq', 10, true);


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 238
-- Name: course_offering_offering_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.course_offering_offering_id_seq', 10, true);


--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 220
-- Name: department_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.department_department_id_seq', 10, true);


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 244
-- Name: enrollment_enrollment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.enrollment_enrollment_id_seq', 20, true);


--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 242
-- Name: exam_schedule_exam_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.exam_schedule_exam_schedule_id_seq', 10, true);


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 246
-- Name: grade_grade_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.grade_grade_id_seq', 17, true);


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 231
-- Name: professor_email_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.professor_email_email_id_seq', 10, true);


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 228
-- Name: professor_professor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.professor_professor_id_seq', 10, true);


--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 236
-- Name: semester_semester_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.semester_semester_id_seq', 11, true);


--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 226
-- Name: student_email_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_email_email_id_seq', 10, true);


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 223
-- Name: student_student_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_student_id_seq', 10, true);


--
-- TOC entry 5055 (class 2606 OID 18008)
-- Name: class_schedule class_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_pkey PRIMARY KEY (class_schedule_id);


--
-- TOC entry 5057 (class 2606 OID 18010)
-- Name: class_schedule class_schedule_room_number_start_time_day_of_week_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_room_number_start_time_day_of_week_key UNIQUE (room_number, start_time, day_of_week);


--
-- TOC entry 5040 (class 2606 OID 17923)
-- Name: course course_course_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_course_code_key UNIQUE (course_code);


--
-- TOC entry 5051 (class 2606 OID 17980)
-- Name: course_offering course_offering_c_id_prof_id_sem_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering
    ADD CONSTRAINT course_offering_c_id_prof_id_sem_id_key UNIQUE (c_id, prof_id, sem_id);


--
-- TOC entry 5053 (class 2606 OID 17978)
-- Name: course_offering course_offering_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering
    ADD CONSTRAINT course_offering_pkey PRIMARY KEY (offering_id);


--
-- TOC entry 5042 (class 2606 OID 17921)
-- Name: course course_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_pkey PRIMARY KEY (course_id);


--
-- TOC entry 5006 (class 2606 OID 19744)
-- Name: department department_department_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_department_name_key UNIQUE (department_name);


--
-- TOC entry 5010 (class 2606 OID 17790)
-- Name: department_phone department_phone_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_phone
    ADD CONSTRAINT department_phone_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 5012 (class 2606 OID 17788)
-- Name: department_phone department_phone_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_phone
    ADD CONSTRAINT department_phone_pkey PRIMARY KEY (dep_id, phone_number);


--
-- TOC entry 5008 (class 2606 OID 17777)
-- Name: department department_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (department_id);


--
-- TOC entry 5063 (class 2606 OID 18056)
-- Name: enrollment enrollment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_pkey PRIMARY KEY (enrollment_id);


--
-- TOC entry 5065 (class 2606 OID 18058)
-- Name: enrollment enrollment_stu_id_offer_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_stu_id_offer_id_key UNIQUE (stu_id, offer_id);


--
-- TOC entry 5059 (class 2606 OID 18032)
-- Name: exam_schedule exam_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam_schedule
    ADD CONSTRAINT exam_schedule_pkey PRIMARY KEY (exam_schedule_id);


--
-- TOC entry 5061 (class 2606 OID 18034)
-- Name: exam_schedule exam_schedule_room_number_start_time_exam_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam_schedule
    ADD CONSTRAINT exam_schedule_room_number_start_time_exam_date_key UNIQUE (room_number, start_time, exam_date);


--
-- TOC entry 5067 (class 2606 OID 18084)
-- Name: grade grade_enroll_id_grade_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grade
    ADD CONSTRAINT grade_enroll_id_grade_type_key UNIQUE (enroll_id, grade_type);


--
-- TOC entry 5069 (class 2606 OID 18082)
-- Name: grade grade_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grade
    ADD CONSTRAINT grade_pkey PRIMARY KEY (grade_id);


--
-- TOC entry 5044 (class 2606 OID 17937)
-- Name: prerequisite prerequisite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prerequisite
    ADD CONSTRAINT prerequisite_pkey PRIMARY KEY (c_id, pre_id);


--
-- TOC entry 5036 (class 2606 OID 17897)
-- Name: professor_email professor_email_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_email
    ADD CONSTRAINT professor_email_email_key UNIQUE (email);


--
-- TOC entry 5038 (class 2606 OID 17895)
-- Name: professor_email professor_email_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_email
    ADD CONSTRAINT professor_email_pkey PRIMARY KEY (email_id);


--
-- TOC entry 5028 (class 2606 OID 17867)
-- Name: professor professor_national_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor
    ADD CONSTRAINT professor_national_code_key UNIQUE (national_code);


--
-- TOC entry 5032 (class 2606 OID 17881)
-- Name: professor_phone professor_phone_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_phone
    ADD CONSTRAINT professor_phone_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 5034 (class 2606 OID 17879)
-- Name: professor_phone professor_phone_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_phone
    ADD CONSTRAINT professor_phone_pkey PRIMARY KEY (prof_id, phone_number);


--
-- TOC entry 5030 (class 2606 OID 17865)
-- Name: professor professor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor
    ADD CONSTRAINT professor_pkey PRIMARY KEY (professor_id);


--
-- TOC entry 5047 (class 2606 OID 17960)
-- Name: semester semester_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.semester
    ADD CONSTRAINT semester_pkey PRIMARY KEY (semester_id);


--
-- TOC entry 5049 (class 2606 OID 17962)
-- Name: semester semester_term_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.semester
    ADD CONSTRAINT semester_term_name_key UNIQUE (term_name);


--
-- TOC entry 5024 (class 2606 OID 17845)
-- Name: student_email student_email_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_email
    ADD CONSTRAINT student_email_email_key UNIQUE (email);


--
-- TOC entry 5026 (class 2606 OID 17843)
-- Name: student_email student_email_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_email
    ADD CONSTRAINT student_email_pkey PRIMARY KEY (email_id);


--
-- TOC entry 5014 (class 2606 OID 17815)
-- Name: student student_national_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_national_code_key UNIQUE (national_code);


--
-- TOC entry 5020 (class 2606 OID 17829)
-- Name: student_phone student_phone_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_phone
    ADD CONSTRAINT student_phone_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 5022 (class 2606 OID 17827)
-- Name: student_phone student_phone_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_phone
    ADD CONSTRAINT student_phone_pkey PRIMARY KEY (stu_id, phone_number);


--
-- TOC entry 5016 (class 2606 OID 17811)
-- Name: student student_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (student_id);


--
-- TOC entry 5018 (class 2606 OID 17813)
-- Name: student student_student_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_student_number_key UNIQUE (student_number);


--
-- TOC entry 5045 (class 1259 OID 18468)
-- Name: one_active_semester; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX one_active_semester ON public.semester USING btree (is_active) WHERE (is_active = true);


--
-- TOC entry 5091 (class 2620 OID 21425)
-- Name: enrollment check_max_units_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_max_units_trigger BEFORE INSERT ON public.enrollment FOR EACH ROW EXECUTE FUNCTION public.check_max_units();


--
-- TOC entry 5083 (class 2606 OID 18016)
-- Name: class_schedule class_schedule_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5084 (class 2606 OID 18011)
-- Name: class_schedule class_schedule_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.course_offering(offering_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5077 (class 2606 OID 17924)
-- Name: course course_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5080 (class 2606 OID 17981)
-- Name: course_offering course_offering_c_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering
    ADD CONSTRAINT course_offering_c_id_fkey FOREIGN KEY (c_id) REFERENCES public.course(course_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5081 (class 2606 OID 17986)
-- Name: course_offering course_offering_prof_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering
    ADD CONSTRAINT course_offering_prof_id_fkey FOREIGN KEY (prof_id) REFERENCES public.professor(professor_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5082 (class 2606 OID 17991)
-- Name: course_offering course_offering_sem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.course_offering
    ADD CONSTRAINT course_offering_sem_id_fkey FOREIGN KEY (sem_id) REFERENCES public.semester(semester_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5070 (class 2606 OID 17791)
-- Name: department_phone department_phone_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department_phone
    ADD CONSTRAINT department_phone_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5087 (class 2606 OID 18064)
-- Name: enrollment enrollment_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.course_offering(offering_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5088 (class 2606 OID 18059)
-- Name: enrollment enrollment_stu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_stu_id_fkey FOREIGN KEY (stu_id) REFERENCES public.student(student_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5085 (class 2606 OID 18040)
-- Name: exam_schedule exam_schedule_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam_schedule
    ADD CONSTRAINT exam_schedule_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5086 (class 2606 OID 18035)
-- Name: exam_schedule exam_schedule_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exam_schedule
    ADD CONSTRAINT exam_schedule_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.course_offering(offering_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5089 (class 2606 OID 18090)
-- Name: grade grade_enroll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grade
    ADD CONSTRAINT grade_enroll_id_fkey FOREIGN KEY (enroll_id) REFERENCES public.enrollment(enrollment_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5090 (class 2606 OID 18085)
-- Name: grade grade_prof_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grade
    ADD CONSTRAINT grade_prof_id_fkey FOREIGN KEY (prof_id) REFERENCES public.professor(professor_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5078 (class 2606 OID 17938)
-- Name: prerequisite prerequisite_c_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prerequisite
    ADD CONSTRAINT prerequisite_c_id_fkey FOREIGN KEY (c_id) REFERENCES public.course(course_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5079 (class 2606 OID 17943)
-- Name: prerequisite prerequisite_pre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prerequisite
    ADD CONSTRAINT prerequisite_pre_id_fkey FOREIGN KEY (pre_id) REFERENCES public.course(course_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5074 (class 2606 OID 17868)
-- Name: professor professor_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor
    ADD CONSTRAINT professor_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5076 (class 2606 OID 17898)
-- Name: professor_email professor_email_prof_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_email
    ADD CONSTRAINT professor_email_prof_id_fkey FOREIGN KEY (prof_id) REFERENCES public.professor(professor_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5075 (class 2606 OID 17882)
-- Name: professor_phone professor_phone_prof_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professor_phone
    ADD CONSTRAINT professor_phone_prof_id_fkey FOREIGN KEY (prof_id) REFERENCES public.professor(professor_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5071 (class 2606 OID 17816)
-- Name: student student_dep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES public.department(department_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5073 (class 2606 OID 17846)
-- Name: student_email student_email_stu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_email
    ADD CONSTRAINT student_email_stu_id_fkey FOREIGN KEY (stu_id) REFERENCES public.student(student_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5072 (class 2606 OID 17830)
-- Name: student_phone student_phone_stu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_phone
    ADD CONSTRAINT student_phone_stu_id_fkey FOREIGN KEY (stu_id) REFERENCES public.student(student_id) ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2026-06-13 15:37:53

--
-- PostgreSQL database dump complete
--

\unrestrict NhMeeOBg8H2IqcSU5KbtnESlL3vVfnRtKQVKgrPgK4shQ93iG461ENwLLzmyjNc

