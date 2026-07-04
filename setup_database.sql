-- ============================================================
-- ATELIER COUTURE — Script base de données
-- Fichier : setup_database.sql
-- Encodage : utf8mb4 | Compatible MySQL 5.7+ / MariaDB 10.3+
-- Exécution : mysql -u root -p < setup_database.sql
--             ou importer via phpMyAdmin
-- ============================================================

CREATE DATABASE IF NOT EXISTS `db_couture`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `db_couture`;

-- ────────────────────────────────────────────────────────────
-- 1. TABLE RENDEZ-VOUS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `rendez_vous` (
  `id`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `nom`              VARCHAR(100)  NOT NULL           COMMENT 'Nom du client',
  `telephone`        VARCHAR(20)   NOT NULL           COMMENT 'Numéro de téléphone',
  `type_prestation`  ENUM(
                       'Consultation + prise de mesures',
                       'Grand Boubou',
                       'Kaftan / Abaya',
                       'Tenue de mariage',
                       'Tenue de baptême',
                       'Tenue de cérémonie',
                       'Retouche / Ajustement',
                       'Commande groupée famille',
                       'Autre'
                     )             NOT NULL           COMMENT 'Type de prestation demandée',
  `date_rdv`         DATE          NOT NULL           COMMENT 'Date souhaitée',
  `heure_pref`       VARCHAR(30)   NULL               COMMENT 'Créneau horaire préféré',
  `message`          TEXT          NULL               COMMENT 'Tissu, inspiration, détails',
  `statut`           ENUM(
                       'en_attente',
                       'confirmé',
                       'en_cours',
                       'terminé',
                       'annulé'
                     )             NOT NULL DEFAULT 'en_attente',
  `created_at`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME      NULL ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  INDEX `idx_date`    (`date_rdv`),
  INDEX `idx_statut`  (`statut`),
  INDEX `idx_tel`     (`telephone`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Rendez-vous clients — Atelier Couture';


-- ────────────────────────────────────────────────────────────
-- 2. TABLE MESURES CLIENTS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `mesures_clients` (
  `id`               INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `nom`              VARCHAR(100)   NOT NULL           COMMENT 'Nom complet du client',
  `telephone`        VARCHAR(20)    NOT NULL           COMMENT 'Identifiant unique du client',
  `genre`            ENUM('Femme','Homme','Enfant') NOT NULL DEFAULT 'Femme',

  -- Mensurations (toutes en cm, DECIMAL pour la précision)
  `poitrine`         DECIMAL(5,1)   NULL               COMMENT 'Tour de poitrine (cm)',
  `taille`           DECIMAL(5,1)   NULL               COMMENT 'Tour de taille (cm)',
  `hanches`          DECIMAL(5,1)   NULL               COMMENT 'Tour de hanches (cm)',
  `longueur_boubou`  DECIMAL(5,1)   NULL               COMMENT 'Longueur totale du boubou (cm)',
  `epaules`          DECIMAL(5,1)   NULL               COMMENT 'Largeur des épaules (cm)',
  `manche`           DECIMAL(5,1)   NULL               COMMENT 'Longueur de la manche (cm)',
  `bras`             DECIMAL(5,1)   NULL               COMMENT 'Tour de bras (cm)',
  `cou`              DECIMAL(5,1)   NULL               COMMENT 'Tour de cou (cm)',
  `hauteur`          DECIMAL(5,1)   NULL               COMMENT 'Hauteur totale / taille (cm)',

  `notes`            TEXT           NULL               COMMENT 'Notes du tailleur',
  `created_at`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME       NULL ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY  `uniq_telephone` (`telephone`),   -- Un seul dossier par numéro
  INDEX `idx_nom` (`nom`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Fiches de mesures clients — Atelier Couture';


-- ────────────────────────────────────────────────────────────
-- 3. VUE : RDV du jour
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW `rdv_aujourd_hui` AS
SELECT id, nom, telephone, type_prestation, heure_pref, statut, message
FROM   `rendez_vous`
WHERE  `date_rdv` = CURDATE()
ORDER BY FIELD(heure_pref, 'Matin 8h-12h','Après-midi 13h-17h','Soir 17h-20h',''), created_at;


-- ────────────────────────────────────────────────────────────
-- 4. VUE : Clients avec mesures complètes
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW `clients_mesures_completes` AS
SELECT id, nom, telephone, genre, poitrine, taille, hanches, longueur_boubou,
       epaules, manche, updated_at
FROM   `mesures_clients`
WHERE  poitrine IS NOT NULL AND taille IS NOT NULL AND hanches IS NOT NULL
ORDER BY nom;


-- ────────────────────────────────────────────────────────────
-- 5. VUE : Statistiques par prestation
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW `stats_prestations` AS
SELECT
  type_prestation,
  COUNT(*)                     AS total,
  SUM(statut='terminé')        AS termines,
  SUM(statut='en_attente')     AS en_attente,
  SUM(statut='annulé')         AS annules,
  MAX(date_rdv)                AS dernier_rdv
FROM `rendez_vous`
GROUP BY type_prestation
ORDER BY total DESC;


-- ────────────────────────────────────────────────────────────
-- 6. Données de test (décommentez pour tester)
-- ────────────────────────────────────────────────────────────
/*
INSERT INTO `rendez_vous` (nom, telephone, type_prestation, date_rdv, heure_pref, message, statut) VALUES
  ('Aminata Diallo', '771234567', 'Grand Boubou',                   '2025-03-10', 'Matin 8h-12h',     'Bazin rose, longueur sol',         'confirmé'),
  ('Ousmane Sarr',   '781234567', 'Kaftan / Abaya',                  '2025-03-12', 'Après-midi 13h-17h', NULL,                             'en_attente'),
  ('Marième Sow',    '701234567', 'Tenue de mariage',               '2025-03-20', 'Soir 17h-20h',     'Famille de 8 personnes',           'en_cours'),
  ('Fatou Niang',    '761234567', 'Consultation + prise de mesures', '2025-03-08', 'Matin 8h-12h',     NULL,                              'terminé');

INSERT INTO `mesures_clients` (nom, telephone, genre, poitrine, taille, hanches, longueur_boubou, epaules, manche, hauteur) VALUES
  ('Aminata Diallo', '771234567', 'Femme',  96.0, 72.0, 102.0, 155.0, 38.5, 58.0, 165.0),
  ('Marième Sow',    '701234567', 'Femme',  88.0, 68.0,  96.0, 150.0, 36.0, 55.0, 162.0),
  ('Ousmane Sarr',   '781234567', 'Homme', 100.0, 84.0, 100.0, 140.0, 44.0, 62.0, 178.0);
*/

-- ────────────────────────────────────────────────────────────
-- FIN DU SCRIPT
-- ────────────────────────────────────────────────────────────
