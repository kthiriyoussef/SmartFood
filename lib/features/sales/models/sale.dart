class SaleLine {
  const SaleLine({
    required this.designation,
    required this.quantity,
    required this.unitPrice,
    this.dishId,
  });
  final String designation;
  final double quantity;
  final int unitPrice;
  final int? dishId;
  int get total => (quantity * unitPrice).round();
  Map<String, Object?> toMap(int saleId) => {
    'vente_id': saleId,
    'designation': designation.trim(),
    'quantite': quantity,
    'prix_unitaire': unitPrice,
    'menu_id': dishId,
  };
}

class Sale {
  const Sale({
    this.id,
    required this.restaurantId,
    required this.date,
    required this.lines,
    this.paymentMode = 'autre',
    this.amountReceived = 0,
    this.status = 'en_attente',
    this.clientUserId,
  });
  final int? id;
  final int restaurantId;
  final DateTime date;
  final List<SaleLine> lines;
  final String paymentMode;
  final int amountReceived;
  final String status;
  final int? clientUserId;
  int get subtotal => lines.fold(0, (sum, line) => sum + line.total);
  int get discountPercent => subtotal >= 50000 ? 10 : 0;
  int get discount => (subtotal * discountPercent / 100).round();
  int get total => subtotal - discount;
}
