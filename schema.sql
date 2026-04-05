-- ============================================================
--  VenteBot — Base de données MySQL
--  Projet SRT L3 — ESP/UCAD
-- ============================================================

CREATE DATABASE IF NOT EXISTS ventebot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ventebot;

-- Catégories produits
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    description TEXT
);

-- Produits
CREATE TABLE produits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(30) UNIQUE NOT NULL,
    nom VARCHAR(150) NOT NULL,
    categorie_id INT,
    prix_achat DECIMAL(10,2) NOT NULL,
    prix_vente DECIMAL(10,2) NOT NULL,
    stock_actuel INT DEFAULT 0,
    stock_minimum INT DEFAULT 5,
    unite VARCHAR(20) DEFAULT 'unité',
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (categorie_id) REFERENCES categories(id)
);

-- Fournisseurs
CREATE TABLE fournisseurs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    telephone VARCHAR(20),
    adresse TEXT,
    delai_livraison_jours INT DEFAULT 7,
    actif BOOLEAN DEFAULT TRUE
);

-- Clients
CREATE TABLE clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE,
    telephone VARCHAR(20),
    adresse TEXT,
    ville VARCHAR(100),
    type_client ENUM('particulier','entreprise','grossiste') DEFAULT 'particulier',
    credit_max DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Commandes
CREATE TABLE commandes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(30) UNIQUE NOT NULL,
    client_id INT NOT NULL,
    date_commande DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_livraison DATE,
    statut ENUM('en_attente','confirmee','expediee','livree','annulee') DEFAULT 'en_attente',
    mode_paiement ENUM('cash','virement','credit','mobile_money') DEFAULT 'cash',
    statut_paiement ENUM('non_paye','partiel','paye') DEFAULT 'non_paye',
    total DECIMAL(10,2) DEFAULT 0,
    notes TEXT,
    FOREIGN KEY (client_id) REFERENCES clients(id)
);

-- Lignes de commande
CREATE TABLE lignes_commande (
    id INT AUTO_INCREMENT PRIMARY KEY,
    commande_id INT NOT NULL,
    produit_id INT NOT NULL,
    quantite INT NOT NULL,
    prix_unitaire DECIMAL(10,2) NOT NULL,
    remise_pct DECIMAL(5,2) DEFAULT 0,
    FOREIGN KEY (commande_id) REFERENCES commandes(id),
    FOREIGN KEY (produit_id) REFERENCES produits(id)
);

-- Mouvements de stock
CREATE TABLE mouvements_stock (
    id INT AUTO_INCREMENT PRIMARY KEY,
    produit_id INT NOT NULL,
    type ENUM('entree','sortie','ajustement') NOT NULL,
    quantite INT NOT NULL,
    reference_doc VARCHAR(50),
    motif TEXT,
    date_mouvement DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produit_id) REFERENCES produits(id)
);

-- ============================================================
--  Données de test
-- ============================================================
INSERT INTO categories (nom, description) VALUES
('Informatique', 'Matériel et accessoires informatiques'),
('Téléphonie', 'Smartphones et accessoires'),
('Bureautique', 'Fournitures de bureau'),
('Réseaux', 'Équipements réseau et câblage');

INSERT INTO produits (reference, nom, categorie_id, prix_achat, prix_vente, stock_actuel, stock_minimum) VALUES
('INFO-001', 'Ordinateur portable HP 15', 1, 350000, 450000, 12, 3),
('INFO-002', 'Souris sans fil Logitech', 1, 8000, 15000, 45, 10),
('INFO-003', 'Clavier USB Azerty', 1, 5000, 10000, 30, 10),
('TEL-001', 'Samsung Galaxy A55', 2, 180000, 230000, 8, 3),
('TEL-002', 'Câble USB-C 2m', 2, 1500, 4000, 120, 20),
('BUR-001', 'Ramette papier A4 500f', 3, 2500, 4500, 3, 10),
('BUR-002', 'Stylos bille (boîte 50)', 3, 2000, 5000, 25, 5),
('RES-001', 'Switch 8 ports TP-Link', 4, 25000, 40000, 6, 2),
('RES-002', 'Câble RJ45 cat6 (bobine 100m)', 4, 15000, 28000, 4, 2),
('RES-003', 'Routeur Wi-Fi TP-Link AC1200', 4, 30000, 50000, 2, 2);

INSERT INTO fournisseurs (nom, email, telephone, delai_livraison_jours) VALUES
('TechDistrib Dakar', 'contact@techdistrib.sn', '+221338001122', 3),
('Informatique Plus', 'vente@infoplus.sn', '+221338002233', 5),
('Global Network SN', 'order@globalnet.sn', '+221338003344', 7);

INSERT INTO clients (nom, email, telephone, ville, type_client, credit_max) VALUES
('Université Cheikh Anta Diop', 'daf@ucad.edu.sn', '+221338591234', 'Dakar', 'entreprise', 5000000),
('Boutique Fatou Diallo', 'fatou.diallo@gmail.com', '+221771234560', 'Thiès', 'particulier', 0),
('Cyber Café Mamadou', 'cyber.mamadou@yahoo.fr', '+221772345671', 'Dakar', 'entreprise', 500000),
('Cabinet Juridique Seck', 'seck@cabinetjuridique.sn', '+221773456782', 'Dakar', 'entreprise', 1000000),
('Grossiste Ndiaye Electronique', 'ndiaye.elec@gmail.com', '+221774567893', 'Saint-Louis', 'grossiste', 3000000);

INSERT INTO commandes (reference, client_id, date_commande, date_livraison, statut, mode_paiement, statut_paiement, total) VALUES
('CMD-2026-001', 1, '2026-03-01 09:00:00', '2026-03-03', 'livree', 'virement', 'paye', 1390000),
('CMD-2026-002', 3, '2026-03-05 11:30:00', '2026-03-06', 'livree', 'cash', 'paye', 290000),
('CMD-2026-003', 5, '2026-03-10 14:00:00', '2026-03-12', 'expediee', 'credit', 'partiel', 870000),
('CMD-2026-004', 2, '2026-03-15 10:00:00', '2026-03-16', 'confirmee', 'mobile_money', 'non_paye', 34000),
('CMD-2026-005', 4, '2026-03-20 15:00:00', '2026-03-22', 'en_attente', 'virement', 'non_paye', 500000);

INSERT INTO lignes_commande (commande_id, produit_id, quantite, prix_unitaire) VALUES
(1, 1, 3, 450000), (1, 8, 1, 40000),
(2, 4, 1, 230000), (2, 2, 4, 15000),
(3, 1, 1, 450000), (3, 9, 3, 28000), (3, 8, 2, 40000),
(4, 6, 5, 4500), (4, 7, 2, 5000),
(5, 3, 10, 10000), (5, 2, 20, 15000), (5, 5, 50, 4000);

INSERT INTO mouvements_stock (produit_id, type, quantite, reference_doc, motif) VALUES
(6, 'sortie', 5, 'CMD-2026-004', 'Vente client'),
(1, 'sortie', 3, 'CMD-2026-001', 'Vente client'),
(1, 'entree', 5, 'ACHAT-2026-012', 'Réapprovisionnement fournisseur'),
(6, 'entree', 10, 'ACHAT-2026-013', 'Réapprovisionnement fournisseur');
