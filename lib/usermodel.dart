class Product {
  final String id;
  final String name;
  final String tamilName;
  final double price;
  final String unit;
  final String category;
  final String barcode;
  final double stock;
  final bool isLocal;

  Product({
    required this.id,
    required this.name,
    required this.tamilName,
    required this.price,
    required this.unit,
    required this.category,
    required this.barcode,
    required this.stock,
    this.isLocal = false,
  });
}

class CartItem {
  final Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}
