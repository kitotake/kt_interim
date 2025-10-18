-- ========================================
-- Script Intérim - Base de données MySQL
-- ========================================

-- Table principale pour les jobs complétés
CREATE TABLE IF NOT EXISTS `kt_interim` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `job_type` VARCHAR(50) NOT NULL,
    `data` TEXT,
    `reward` INT(11) DEFAULT 0,
    `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_job_type` (`job_type`),
    INDEX `idx_completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table pour les statistiques des joueurs
CREATE TABLE IF NOT EXISTS `interim_player_stats` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `total_jobs` INT(11) DEFAULT 0,
    `total_earned` INT(11) DEFAULT 0,
    `reputation_level` INT(11) DEFAULT 1,
    `reputation_xp` INT(11) DEFAULT 0,
    `last_job_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_reputation_level` (`reputation_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table pour les quêtes journalières
CREATE TABLE IF NOT EXISTS `interim_daily_quests` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `quest_date` DATE NOT NULL,
    `job_type` VARCHAR(50) NOT NULL,
    `progress` INT(11) DEFAULT 0,
    `required_amount` INT(11) NOT NULL,
    `completed` TINYINT(1) DEFAULT 0,
    `reward_claimed` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier_date` (`identifier`, `quest_date`),
    INDEX `idx_quest_date` (`quest_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table pour les bans temporaires
CREATE TABLE IF NOT EXISTS `interim_bans` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `reason` TEXT,
    `banned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `ban_duration` INT(11) DEFAULT 0 COMMENT 'Durée en secondes, 0 = permanent',
    `expires_at` TIMESTAMP NULL,
    `active` TINYINT(1) DEFAULT 1,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table pour les logs détaillés (optionnel, pour admin)
CREATE TABLE IF NOT EXISTS `interim_logs` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50),
    `log_type` VARCHAR(50) NOT NULL COMMENT 'INFO, WARN, ERROR, SUCCESS, etc.',
    `job_type` VARCHAR(50),
    `message` TEXT,
    `data` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_log_type` (`log_type`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vue pour les statistiques par job
CREATE OR REPLACE VIEW `interim_job_statistics` AS
SELECT 
    job_type,
    COUNT(*) as total_completions,
    AVG(reward) as avg_reward,
    SUM(reward) as total_rewards,
    COUNT(DISTINCT identifier) as unique_players,
    MIN(completed_at) as first_completion,
    MAX(completed_at) as last_completion
FROM kt_interim
GROUP BY job_type;

-- Vue pour le classement des joueurs
CREATE OR REPLACE VIEW `interim_player_leaderboard` AS
SELECT 
    ps.identifier,
    ps.total_jobs,
    ps.total_earned,
    ps.reputation_level,
    ps.reputation_xp,
    RANK() OVER (ORDER BY ps.total_earned DESC) as rank_by_earnings,
    RANK() OVER (ORDER BY ps.reputation_level DESC, ps.reputation_xp DESC) as rank_by_reputation,
    RANK() OVER (ORDER BY ps.total_jobs DESC) as rank_by_jobs
FROM interim_player_stats ps
ORDER BY ps.total_earned DESC;

-- Procédure stockée pour mettre à jour les stats d'un joueur
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `UpdatePlayerStats`(
    IN p_identifier VARCHAR(50),
    IN p_reward INT,
    IN p_xp_gain INT
)
BEGIN
    INSERT INTO interim_player_stats (identifier, total_jobs, total_earned, reputation_xp, last_job_at)
    VALUES (p_identifier, 1, p_reward, p_xp_gain, NOW())
    ON DUPLICATE KEY UPDATE
        total_jobs = total_jobs + 1,
        total_earned = total_earned + p_reward,
        reputation_xp = reputation_xp + p_xp_gain,
        last_job_at = NOW();
        
    -- Vérifier si level up
    UPDATE interim_player_stats
    SET 
        reputation_level = reputation_level + 1,
        reputation_xp = reputation_xp - (reputation_level * 100)
    WHERE 
        identifier = p_identifier 
        AND reputation_xp >= (reputation_level * 100);
END$$
DELIMITER ;

-- Procédure pour nettoyer les anciennes quêtes
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `CleanOldQuests`()
BEGIN
    DELETE FROM interim_daily_quests
    WHERE quest_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY);
END$$
DELIMITER ;

-- Procédure pour nettoyer les vieux logs
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `CleanOldLogs`()
BEGIN
    DELETE FROM interim_logs
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
END$$
DELIMITER ;

-- Event pour nettoyer automatiquement les anciennes données (exécuté quotidiennement)
CREATE EVENT IF NOT EXISTS `interim_daily_cleanup`
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    CALL CleanOldQuests();
    CALL CleanOldLogs();
    
    -- Désactiver les bans expirés
    UPDATE interim_bans
    SET active = 0
    WHERE active = 1 
      AND expires_at IS NOT NULL 
      AND expires_at < NOW();
END;

-- Données de test (optionnel, à supprimer en production)
-- INSERT INTO kt_interim (identifier, job_type, data, reward) VALUES
-- ('license:test123', 'construction', '{"items":10}', 150),
-- ('license:test123', 'cleaning', '{"items":5}', 120),
-- ('license:test456', 'taxi', '{"distance":2500}', 225);

-- Requêtes utiles pour les admins
-- 
-- Top 10 joueurs par gains:
-- SELECT * FROM interim_player_leaderboard LIMIT 10;
-- 
-- Statistiques globales:
-- SELECT * FROM interim_job_statistics;
-- 
-- Jobs d'un joueur spécifique:
-- SELECT * FROM kt_interim WHERE identifier = 'license:xxxxx' ORDER BY completed_at DESC;
-- 
-- Activité récente (dernières 24h):
-- SELECT job_type, COUNT(*) as count FROM kt_interim 
-- WHERE completed_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
-- GROUP BY job_type;

PRINT '✅ Base de données Interim installée avec succès !';