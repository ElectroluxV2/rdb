create table if not exists clubs (
    club_id int not null auto_increment,
    short_name varchar(64) not null,
    full_name varchar(256) not null,
    primary key (club_id)
);

create table if not exists sailors (
    sailor_id int not null auto_increment,
    club_id int not null,
    given_name varchar(128) not null,
    family_name varchar(128) not null,
    birth_date datetime not null,
    primary key (sailor_id),
    constraint fk_sailors_clubs_club_id foreign key (club_id) references clubs(club_id) on delete cascade
);

create table if not exists regattas (
    regatta_id int not null auto_increment,
    name varchar(512) not null,
    year int not null,
    cup_multiplier float not null,
    primary key (regatta_id)
);

create table if not exists starting_list (
    entry_id int not null auto_increment,
    sailor_id int not null,
    regatta_id int not null,
    sail_number varchar(10) not null,
    confirmed boolean default false,
    primary key (entry_id),
    constraint fk_starting_list_sailors_sailor_id foreign key (sailor_id) references sailors(sailor_id) on delete cascade,
    constraint fk_starting_list_regattas_regatta_id foreign key (regatta_id) references regattas(regatta_id) on delete cascade
);

create table if not exists races (
    race_id int not null auto_increment,
    regatta_id int not null,
    name int not null,
    primary key (race_id),
    constraint fk_races_regattas_regatta_id foreign key (regatta_id) references regattas(regatta_id) on delete cascade
);

create table if not exists race_results (
    race_id int not null,
    sail_number varchar(10) not null,
    place int not null,
    primary key (race_id, sail_number),
    constraint fk_race_results_races_race_id foreign key (race_id) references races(race_id) on delete cascade
);

create table if not exists year_categories (
  category varchar(16) not null unique,
  younger_than int not null,
  primary key (category)
);

delimiter $$
drop function if exists get_age_from_birthdate;
create function if not exists get_age_from_birthdate(birth_date datetime) returns integer
begin
    return year(current_timestamp) - year(birth_date) - (right(current_timestamp, 5) < right(birth_date, 5));
end$$
delimiter ;

delimiter $$
drop function if exists get_category_from_age;
create function if not exists get_category_from_age(year integer) returns varchar(16)
begin
    declare category_but_this_time_not_ambiguous varchar(16);

    set category_but_this_time_not_ambiguous = (select category from year_categories where younger_than > year order by younger_than limit 1);

    return category_but_this_time_not_ambiguous;
end$$
delimiter ;

delimiter $$
drop function if exists get_category_from_birthdate;
create function if not exists get_category_from_birthdate(birth_date datetime) returns varchar(16)
begin
    return get_category_from_age(get_age_from_birthdate(birth_date));
end$$
delimiter ;

delimiter $$
drop procedure if exists get_starting_list_by_regatta_id;
create procedure get_starting_list_by_regatta_id(regatta_id integer)
begin
    select sailors.given_name,
       sailors.family_name,
       starting_list.sail_number,
       clubs.short_name as club_short_name,
       get_category_from_birthdate(sailors.birth_date) as category from sailors
           join starting_list on sailors.sailor_id = starting_list.sailor_id
           join clubs on clubs.club_id = sailors.club_id
    where starting_list.regatta_id = 1;
end $$
delimiter ;

delimiter $$
drop procedure if exists create_results_view_for_regatta;
create procedure create_results_view_for_regatta(for_regatta_id integer)
begin
    declare name varchar(100);
    set name = (concat('view_regatta_results_', for_regatta_id));
    create view name as
        select sum(place) as points
        from race_results
        join races on race_results.race_id = races.race_id
        where regatta_id = 12
        group by sail_number;

end$$
delimiter ;

create trigger create_results_view_on_regatta_insert after update on regattas for each row call create_results_view_for_regatta(regatta_id);
