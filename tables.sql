    create table department (
	department_id SERIAL PRIMARY KEY ,
	department_name VARCHAR(50) NOT NULL  unique,
	faculty_name VARCHAR(50)  
);
create table department_phone (
    dep_id integer not null,
    phone_number varchar(11) unique,
    PRIMARY KEY(dep_id, phone_number),
    FOREIGN KEY (dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table student (
	student_id SERIAL PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    student_number varchar(10) unique not null,
    national_code varchar(10) unique not null,
    date_of_birth date,
    entry_year integer check(entry_year >= 1398),
    password varchar(255) not null,
    dep_id integer not null,
    FOREIGN KEY(dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table student_phone (
    stu_id integer not null,
    phone_number varchar(11) unique,
    PRIMARY KEY(stu_id, phone_number),
    FOREIGN KEY (stu_id) REFERENCES student(student_id) on delete cascade on update cascade 
);
create table student_email (
    email_id SERIAL PRIMARY KEY,
    stu_id integer not null,
    email varchar(255) unique,
    FOREIGN KEY (stu_id) REFERENCES student(student_id) on delete cascade on update cascade  
);
create table professor (
	professor_id SERIAL PRIMARY KEY ,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    academic_rank varchar(20) check(academic_rank in ('استاد یار', 'استاد','دانشیار','مربی')),
    national_code varchar(10) unique not null,
    date_of_birth date,
    password varchar(255) not null,
    dep_id integer not null,
    FOREIGN KEY(dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table professor_phone (
    prof_id integer not null,
    phone_number varchar(11) unique,
    PRIMARY KEY(prof_id, phone_number),
    FOREIGN KEY (prof_id) REFERENCES professor(professor_id) on delete cascade on update cascade 
);
create table professor_email (
    email_id SERIAL PRIMARY KEY,
    prof_id integer not null,
    email varchar(255) unique,
    FOREIGN KEY (prof_id) REFERENCES professor(professor_id) on delete cascade on update cascade  
);
create table course (
	course_id SERIAL PRIMARY KEY,
	course_code varchar(20) NOT NULL unique,
	name VARCHAR(50) NOT NULL,
	description text,
    course_type VARCHAR(20) NOT NULL check(course_type in ('پایه','تخصصی','عمومی','اختیاری','عملی','نظری')),
    credits integer not null check(credits >=0 and credits <=4),
    is_active boolean not null default FALSE,
    dep_id integer not null,
    FOREIGN KEY(dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table prerequisite (
    c_id integer not null,
	pre_id integer not null,
    min_grade numeric(4,2) default 10.00,
    pre_type varchar(20) check(pre_type in ('پیش نیاز','هم نیاز')),
    PRIMARY KEY(c_id, pre_id),
    FOREIGN KEY(c_id) REFERENCES course(course_id) on delete cascade on update cascade,
    FOREIGN KEY(pre_id) REFERENCES course(course_id) on delete cascade on update cascade
);
create table semester (
	semester_id SERIAL PRIMARY KEY,
    term_name varchar(20) unique not null,
	start_date date,
	end_date date,
	registration_start_date date,
	registration_end_date date,
    is_active boolean not null default FALSE,
    check(start_date < end_date),
    check(registration_start_date < registration_end_date)
);
create table course_offering (
    offering_id SERIAL PRIMARY KEY,
    status VARCHAR(20) NOT NULL check(status in ('غیر قابل اخذ','قابل اخذ')),
    capacity integer default 0, 
    registered_count integer default 0,
    CHECK (registered_count <= capacity),
    c_id integer not null,
    prof_id integer not null,
    sem_id integer not null,
    UNIQUE(c_id, prof_id, sem_id),
    FOREIGN KEY(c_id) REFERENCES course(course_id) on delete cascade on update cascade,
    FOREIGN KEY(prof_id) REFERENCES professor(professor_id) on delete cascade on update cascade,
    FOREIGN KEY(sem_id) REFERENCES semester(semester_id) on delete cascade on update cascade
);
create table class_schedule(
	class_schedule_id SERIAL PRIMARY KEY,
    room_number integer,
	start_time time,
	end_time time,
    day_of_week varchar(20),
    check(start_time < end_time),
    check(end_time - start_time = INTERVAL '2 hours'),
    check(day_of_week in ('شنبه','یکشنبه','دوشنبه','سه شنبه','چهارشنبه','پنجشنبه','جمعه')),
    offer_id integer not null,
    dep_id integer not null,
    UNIQUE(room_number, start_time, day_of_week),
    FOREIGN KEY(offer_id) REFERENCES course_offering(offering_id) on delete cascade on update cascade,
    FOREIGN KEY(dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table exam_schedule(
	exam_schedule_id SERIAL PRIMARY KEY,
    room_number integer,
	start_time time,
	end_time time,
    exam_date date,
    check(start_time < end_time),
    check(end_time - start_time = INTERVAL '2 hours'),
    offer_id integer not null,
    dep_id integer not null,
    UNIQUE(room_number, start_time, exam_date),
    FOREIGN KEY(offer_id) REFERENCES course_offering(offering_id) on delete cascade on update cascade,
    FOREIGN KEY(dep_id) REFERENCES department(department_id) on delete cascade on update cascade
);
create table enrollment (
	enrollment_id SERIAL PRIMARY KEY,
	enrollment_date timestamp DEFAULT CURRENT_TIMESTAMP,
    status varchar(20) check(status in ('قبول','رد','ثبت نام نهایی','ثبت نام موقت','حذف اضطراری')),
    offer_id integer not null,
    stu_id integer not null,
    UNIQUE(stu_id,offer_id),
    FOREIGN KEY(stu_id) REFERENCES student(student_id) on delete cascade on update cascade,
    FOREIGN KEY(offer_id) REFERENCES course_offering(offering_id) on delete cascade on update cascade
);
create table grade (
	grade_id SERIAL PRIMARY KEY,
    grade_type varchar(30) not null check(grade_type in ('نهایی','میان ترم', 'پایان ترم', 'تمرین', 'پروژه', 'کوئیز')),
	numeric_grade numeric(4,2) check(numeric_grade between 0.00 and 20.00),
    letter_grade varchar(50),
    grade_date date default CURRENT_DATE,
    prof_id integer not null,
    enroll_id integer not null,
    UNIQUE(enroll_id, grade_type),
    FOREIGN KEY(prof_id) REFERENCES professor(professor_id) on delete cascade on update cascade,
    FOREIGN KEY(enroll_id) REFERENCES enrollment(enrollment_id) on delete cascade on update cascade
);






