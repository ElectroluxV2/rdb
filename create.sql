drop table if exists clubs cascade;
create table clubs (
    club_id int not null auto_increment,
    short_name varchar(64) not null,
    full_name varchar(256) not null,
    primary key (club_id)
);

drop table if exists sailors cascade;
create table sailors (
    sailor_id int not null auto_increment,
    club_id int not null,
    given_name varchar(128) not null,
    family_name varchar(128) not null,
    birth_date datetime not null,
    primary key (sailor_id),
    constraint fk_sailors_clubs_club_id foreign key (club_id) references clubs(club_id) on delete cascade
);

drop table if exists regattas cascade;
create table regattas (
    regatta_id int not null auto_increment,
    name varchar(512) not null,
    year int not null,
    cup_multiplier float not null,
    primary key (regatta_id)
);

drop table if exists starting_list cascade;
create table starting_list (
    entry_id int not null auto_increment,
    sailor_id int not null,
    regatta_id int not null,
    sail_number varchar(10) not null,
    confirmed boolean default false,
    primary key (entry_id),
    constraint fk_starting_list_sailors_sailor_id foreign key (sailor_id) references sailors(sailor_id) on delete cascade,
    constraint fk_starting_list_regattas_regatta_id foreign key (regatta_id) references regattas(regatta_id) on delete cascade
);

drop table if exists races cascade;
create table races (
    race_id int not null auto_increment,
    regatta_id int not null,
    number int not null,
    name tinytext,
    primary key (race_id),
    constraint single_race_number_for_regatta unique (regatta_id, number),
    constraint fk_races_regattas_regatta_id foreign key (regatta_id) references regattas(regatta_id) on delete cascade
);

drop table if exists results_abbreviations cascade;
create table results_abbreviations (
    short_name varchar(5) not null unique,
    full_name varchar(255) not null,
    primary key (short_name)
);

drop table if exists race_results cascade;
create table race_results (
    race_id int not null,
    sail_number varchar(10) not null,
    place int not null ,
    abbreviation varchar(5) default null,
    points int,
    primary key (race_id, sail_number),
    constraint fk_race_results_races_race_id foreign key (race_id) references races(race_id) on delete cascade,
    constraint fk_race_results_results_abbreviations_abbreviation foreign key (abbreviation) references results_abbreviations(short_name) on delete cascade
);

drop table if exists year_categories cascade;
create table year_categories (
  category varchar(16) not null unique,
  younger_than int not null,
  primary key (category)
);

delimiter $$
drop function if exists get_age_from_birthdate;
create function if not exists get_age_from_birthdate(birth_date datetime) returns integer
begin
    return year(current_timestamp) - year(birth_date) - (right(current_timestamp, 5) < right(birth_date, 5));
end; $$
delimiter ;

delimiter $$
drop function if exists get_category_from_age;
create function if not exists get_category_from_age(year integer) returns varchar(16)
begin
    declare category_but_this_time_not_ambiguous varchar(16);

    set category_but_this_time_not_ambiguous = (select category from year_categories where younger_than > year order by younger_than limit 1);

    return category_but_this_time_not_ambiguous;
end; $$
delimiter ;

delimiter $$
drop function if exists get_category_from_birthdate;
create function if not exists get_category_from_birthdate(birth_date datetime) returns varchar(16)
begin
    return get_category_from_age(get_age_from_birthdate(birth_date));
end; $$
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
end; $$
delimiter ;

delimiter $$
drop function if exists get_points_for_race_result;
create function get_points_for_race_result(total_competitors integer, place integer, abbreviation varchar(5)) returns integer
begin
    declare points integer;

    if abbreviation is null then
        set points = place;
    else
        set points = total_competitors + 1;
    end if;

    return points;

end; $$
delimiter ;

delimiter $$
drop function if exists get_regatta_id_from_race_id;
create function if not exists get_regatta_id_from_race_id(race_id integer) returns integer
begin
    declare found_regatta_id varchar(16);

    set found_regatta_id = (select regatta_id from races where races.race_id = race_id);

    return found_regatta_id;
end; $$
delimiter ;

delimiter $$
drop function if exists get_total_competitors_by_regatta_id;
create function if not exists get_total_competitors_by_regatta_id(regatta_id integer) returns integer
begin
    declare total_competitors varchar(16);

    set total_competitors = (select count(sail_number) from starting_list where starting_list.regatta_id = regatta_id);

    return total_competitors;
end; $$
delimiter ;

delimiter $$
drop procedure if exists update_points_for_race_result;
create procedure update_points_for_race_result(new_place integer, new_abbreviation varchar(5), new_race_id integer)
begin
    declare total_competitors integer;
    set total_competitors = get_total_competitors_by_regatta_id(get_regatta_id_from_race_id(new_race_id));

    update race_results set points = get_points_for_race_result(total_competitors, new_place, new_abbreviation) where race_id = new_race_id and sail_number = new_abbreviation;
end; $$
delimiter ;

delimiter $$
drop trigger if exists calculate_points_for_race_result;
create trigger calculate_points_for_race_result before insert on race_results for each row
begin
    set new.points = get_points_for_race_result(get_total_competitors_by_regatta_id(get_regatta_id_from_race_id(new.race_id)), new.place, new.abbreviation);
end; $$
delimiter ;

delimiter $$
drop trigger if exists recalculate_points_for_race_result;
create trigger recalculate_points_for_race_result before update on race_results for each row
begin
    set new.points = get_points_for_race_result(get_total_competitors_by_regatta_id(get_regatta_id_from_race_id(new.race_id)), new.place, new.abbreviation);
end; $$
delimiter ;

delimiter $$
drop function if exists is_sail_number_present_in_starting_list;
create function if not exists is_sail_number_present_in_starting_list(sail_number varchar(10), regatta_id integer) returns boolean
begin
    declare entriesCount integer;

    set entriesCount = (select count(entry_id) as entriesCount from starting_list where starting_list.regatta_id = regatta_id and starting_list.sail_number = sail_number);

    return entriesCount = 1;
end; $$
delimiter ;

delimiter $$
drop trigger if exists prevent_sail_number_insert_to_race_results;
create trigger prevent_sail_number_insert_to_race_results before insert on race_results for each row
begin
    if not is_sail_number_present_in_starting_list(new.sail_number, get_regatta_id_from_race_id(new.race_id)) then
    signal sqlstate '45000';
    end if;
end; $$
delimiter ;
