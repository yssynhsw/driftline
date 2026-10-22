class Trip {
  const Trip({
    required this.id,
    required this.titre,
    required this.destination,
    required this.pays,
    required this.dateDepart,
    required this.dateRetour,
    required this.budget,
    required this.nombreVoyageurs,
    required this.typeVoyage,
    required this.statut,
    required this.userId,
    required this.dateCreation,
  });

  final int id;
  final String titre;
  final String destination;
  final String pays;
  final String dateDepart;
  final String dateRetour;
  final double budget;
  final int nombreVoyageurs;
  final String typeVoyage;
  final String statut;
  final int userId;
  final DateTime dateCreation;
}
