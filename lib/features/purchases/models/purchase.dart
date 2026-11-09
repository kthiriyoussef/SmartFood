class PurchaseLine {
  const PurchaseLine({
    required this.designation,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });
  final String designation;
  final double quantity;
  final String unit;
  final int unitPrice;
  int get total => (quantity * unitPrice).round();
  Map<String, Object?> toMap(int purchaseId) => {
    'achat_id': purchaseId,
    'designation': designation.trim(),
    'quantite': quantity,
    'unite': unit,
    'prix_unitaire': unitPrice,
  };
}

class Purchase {
  const Purchase({
    this.id,
    required this.supplierId,
    required this.restaurantId,
    required this.date,
    required this.expectedDate,
    required this.lines,
    this.status = 'en_attente',
  });
  final int? id;
  final int supplierId, restaurantId;
  final DateTime date, expectedDate;
  final List<PurchaseLine> lines;
  final String status;
  int get total => lines.fold(0, (sum, line) => sum + line.total);
}
