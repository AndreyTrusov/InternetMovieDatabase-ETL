-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Jan 12, 2025 at 08:47 PM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.0.28

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `image_git`
--

-- --------------------------------------------------------

--
-- Table structure for table `dim_genre`
--

CREATE TABLE `dim_genre` (
  `genre_id` int(11) NOT NULL,
  `genre_name` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_location`
--

CREATE TABLE `dim_location` (
  `location_id` int(11) NOT NULL,
  `country` varchar(250) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_movie`
--

CREATE TABLE `dim_movie` (
  `movie_id` varchar(10) NOT NULL,
  `title` varchar(200) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL,
  `languages` varchar(200) DEFAULT NULL,
  `production_company` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_person`
--

CREATE TABLE `dim_person` (
  `person_id` varchar(10) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `known_for_movies` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_time`
--

CREATE TABLE `dim_time` (
  `time_id` int(11) NOT NULL,
  `full_date` date DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `month` int(11) DEFAULT NULL,
  `day` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `fact_movies`
--

CREATE TABLE `fact_movies` (
  `movie_id` varchar(10) NOT NULL,
  `person_id` varchar(10) NOT NULL,
  `genre_id` int(11) NOT NULL,
  `time_id` int(11) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `role_category` varchar(10) DEFAULT NULL,
  `avg_rating` decimal(3,1) DEFAULT NULL,
  `total_votes` int(11) DEFAULT NULL,
  `median_rating` int(11) DEFAULT NULL,
  `worldwide_gross_income` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `dim_genre`
--
ALTER TABLE `dim_genre`
  ADD PRIMARY KEY (`genre_id`),
  ADD UNIQUE KEY `genre_name` (`genre_name`);

--
-- Indexes for table `dim_location`
--
ALTER TABLE `dim_location`
  ADD PRIMARY KEY (`location_id`),
  ADD UNIQUE KEY `country` (`country`);

--
-- Indexes for table `dim_movie`
--
ALTER TABLE `dim_movie`
  ADD PRIMARY KEY (`movie_id`);

--
-- Indexes for table `dim_person`
--
ALTER TABLE `dim_person`
  ADD PRIMARY KEY (`person_id`);

--
-- Indexes for table `dim_time`
--
ALTER TABLE `dim_time`
  ADD PRIMARY KEY (`time_id`);

--
-- Indexes for table `fact_movies`
--
ALTER TABLE `fact_movies`
  ADD PRIMARY KEY (`movie_id`,`person_id`,`genre_id`),
  ADD KEY `person_id` (`person_id`),
  ADD KEY `genre_id` (`genre_id`),
  ADD KEY `time_id` (`time_id`),
  ADD KEY `location_id` (`location_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `dim_genre`
--
ALTER TABLE `dim_genre`
  MODIFY `genre_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dim_location`
--
ALTER TABLE `dim_location`
  MODIFY `location_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `fact_movies`
--
ALTER TABLE `fact_movies`
  ADD CONSTRAINT `fact_movies_ibfk_1` FOREIGN KEY (`movie_id`) REFERENCES `dim_movie` (`movie_id`),
  ADD CONSTRAINT `fact_movies_ibfk_2` FOREIGN KEY (`person_id`) REFERENCES `dim_person` (`person_id`),
  ADD CONSTRAINT `fact_movies_ibfk_3` FOREIGN KEY (`genre_id`) REFERENCES `dim_genre` (`genre_id`),
  ADD CONSTRAINT `fact_movies_ibfk_4` FOREIGN KEY (`time_id`) REFERENCES `dim_time` (`time_id`),
  ADD CONSTRAINT `fact_movies_ibfk_5` FOREIGN KEY (`location_id`) REFERENCES `dim_location` (`location_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
