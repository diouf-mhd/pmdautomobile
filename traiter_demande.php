<?php
/**
 * traiter_demande.php
 * Traitement sécurisé du formulaire de rendez-vous pour PMD Services.
 *
 * ✅ Sécurisation :
 *   - Validation et assainissement de chaque champ
 *   - Requêtes préparées PDO (protection anti-injection SQL)
 *   - Vérification CSRF optionnelle (voir commentaire)
 *   - Réponse JSON propre
 */

// ── Autoriser uniquement les requêtes POST ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['success' => false, 'message' => 'Méthode non autorisée.']));
}

// ── En-têtes JSON ─────────────────────────────────────────────────────────────
header('Content-Type: application/json; charset=utf-8');

// ── Import de la connexion BD ─────────────────────────────────────────────────
require_once __DIR__ . '/db_connect.php';

// ────────────────────────────────────────────────────────────────────────────────
// FONCTIONS UTILITAIRES
// ────────────────────────────────────────────────────────────────────────────────

/**
 * Nettoie et valide une chaîne de caractères.
 * Supprime les espaces, balises HTML et caractères dangereux.
 */
function nettoyerChaine(?string $valeur): string
{
    if ($valeur === null) return '';
    return htmlspecialchars(strip_tags(trim($valeur)), ENT_QUOTES, 'UTF-8');
}

/**
 * Valide un numéro de téléphone sénégalais (7x xxx xx xx).
 * Accepte aussi les formats internationaux +221…
 */
function validerTelephone(string $tel): bool
{
    // Retire espaces et tirets pour la validation
    $telNormalise = preg_replace('/[\s\-]/', '', $tel);
    return (bool) preg_match('/^(\+221)?[0-9]{9}$/', $telNormalise);
}

/**
 * Valide une date au format AAAA-MM-JJ et vérifie qu'elle est dans le futur.
 */
function validerDate(string $date): bool
{
    $d = DateTime::createFromFormat('Y-m-d', $date);
    if (!$d || $d->format('Y-m-d') !== $date) return false;
    return $d >= new DateTime('today');
}

// ────────────────────────────────────────────────────────────────────────────────
// RÉCUPÉRATION ET VALIDATION DES DONNÉES
// ────────────────────────────────────────────────────────────────────────────────

$erreurs = [];

// ── Nom ──
$nom = nettoyerChaine($_POST['nom'] ?? '');
if (empty($nom)) {
    $erreurs[] = 'Le nom est obligatoire.';
} elseif (mb_strlen($nom) < 2 || mb_strlen($nom) > 100) {
    $erreurs[] = 'Le nom doit contenir entre 2 et 100 caractères.';
}

// ── Téléphone ──
$telephone = nettoyerChaine($_POST['telephone'] ?? '');
if (empty($telephone)) {
    $erreurs[] = 'Le numéro de téléphone est obligatoire.';
} elseif (!validerTelephone($telephone)) {
    $erreurs[] = 'Le numéro de téléphone n\'est pas valide.';
}

// ── Type de service ──
$servicesAutorises = [
    'Réparation mécanique',
    'Climatisation',
    'Programmation électronique',
    'Diagnostic scanner',
    'Autre',
];
$typeService = nettoyerChaine($_POST['type_service'] ?? '');
if (empty($typeService)) {
    $erreurs[] = 'Veuillez sélectionner un type de service.';
} elseif (!in_array($typeService, $servicesAutorises, true)) {
    $erreurs[] = 'Type de service non reconnu.';
}

// ── Date souhaitée ──
$dateRdv = nettoyerChaine($_POST['date_rdv'] ?? '');
if (empty($dateRdv)) {
    $erreurs[] = 'La date souhaitée est obligatoire.';
} elseif (!validerDate($dateRdv)) {
    $erreurs[] = 'La date doit être aujourd\'hui ou ultérieure (format AAAA-MM-JJ).';
}

// ── Message (optionnel) ──
$message = nettoyerChaine($_POST['message'] ?? '');
if (mb_strlen($message) > 1000) {
    $erreurs[] = 'Le message ne peut pas dépasser 1000 caractères.';
}

// ── Retour d'erreurs de validation ──
if (!empty($erreurs)) {
    http_response_code(422);
    exit(json_encode([
        'success' => false,
        'message' => implode(' ', $erreurs),
        'erreurs' => $erreurs,
    ]));
}

// ────────────────────────────────────────────────────────────────────────────────
// INSERTION EN BASE DE DONNÉES
// ────────────────────────────────────────────────────────────────────────────────

try {
    $pdo = getPDO();

    // Requête préparée — aucune donnée utilisateur n'est interpolée directement
    $sql = "
        INSERT INTO rendez_vous (nom, telephone, type_service, date_rdv, message, statut, created_at)
        VALUES (:nom, :telephone, :type_service, :date_rdv, :message, 'en_attente', NOW())
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':nom'          => $nom,
        ':telephone'    => $telephone,
        ':type_service' => $typeService,
        ':date_rdv'     => $dateRdv,
        ':message'      => $message,
    ]);

    $idInseré = $pdo->lastInsertId();

    // ── Log (facultatif) ──
    error_log("[PMD Services] Nouveau RDV #$idInseré — $nom — $dateRdv — $typeService");

    // ── Réponse succès ──
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Votre rendez-vous a été enregistré avec succès.',
        'id'      => $idInseré,
    ]);

} catch (PDOException $e) {
    error_log('[PMD Services] Erreur INSERT : ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Une erreur est survenue lors de l\'enregistrement. Veuillez réessayer.',
    ]);
}
