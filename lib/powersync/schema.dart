import 'package:powersync/powersync.dart';

const schema = Schema([
  Table('products', [
    Column.text('name'),
    Column.text('category'),
    Column.text('price'),
    Column.integer('stock'),
    Column.text('barcode'),
    Column.text('imagepath'),
    Column.text('updatedat'),
  ]),
  Table('customers', [
    Column.text('name'),
    Column.text('phone'),
    Column.text('createdat'),
  ]),
  Table('sales', [
    Column.text('totalamount'),
    Column.text('discount'),
    Column.text('createdat'),
    Column.text('paymenttype'),
    Column.text('customerid'),
  ]),
  Table('sale_items', [
    Column.text('saleid'),
    Column.text('productid'),
    Column.text('productname'),
    Column.integer('quantity'),
    Column.text('priceatsale'),
  ]),
  Table('udhar_payments', [
    Column.text('customerid'),
    Column.text('amount'),
    Column.text('createdat'),
  ]),
  Table('settings', [
    Column.text('key'),
    Column.text('value'),
  ]),
]);