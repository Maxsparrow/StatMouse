TRUNCATE TABLE games;

SELECT * from games WHERE createDate < '2014-09-01';

LOAD DATA LOCAL INFILE 'C:/Users/Maxsparrow/Documents/MasterFinalGames.csv' INTO TABLE statmous_gamedata.games 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES;