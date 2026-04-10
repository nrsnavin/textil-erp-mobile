import 'package:flutter/material.dart' show Color;

// ── Auth ──────────────────────────────────────────────────────────────────────

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final bool   mfaRequired;
  final String? mfaToken;
  final UserProfile? user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    this.mfaRequired = false,
    this.mfaToken,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    accessToken:  j['accessToken']  ?? '',
    refreshToken: j['refreshToken'] ?? '',
    mfaRequired:  j['mfaRequired']  ?? false,
    mfaToken:     j['mfaToken'],
    user:         j['user'] != null ? UserProfile.fromJson(j['user']) : null,
  );
}

class UserProfile {
  final String id;
  final String tenantId;
  final String name;
  final String email;
  final String role;

  UserProfile({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id:       j['id']       ?? '',
    tenantId: j['tenantId'] ?? '',
    name:     j['name']     ?? '',
    email:    j['email']    ?? '',
    role:     j['role']     ?? '',
  );
}

// ── Pagination ────────────────────────────────────────────────────────────────

class PaginatedResponse<T> {
  final List<T> data;
  final PaginationMeta meta;

  PaginatedResponse({required this.data, required this.meta});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      PaginatedResponse(
        data: (j['data'] as List<dynamic>).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        meta: PaginationMeta.fromJson(j['meta'] as Map<String, dynamic>),
      );
}

class PaginationMeta {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> j) => PaginationMeta(
    page:  j['page']  ?? 1,
    limit: j['limit'] ?? 20,
    total: j['total'] ?? 0,
    pages: j['pages'] ?? 0,
  );
}

// ── Item ──────────────────────────────────────────────────────────────────────

class Item {
  final String  id;
  final String  code;
  final String  name;
  final String  unit;
  final String? category;

  Item({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    this.category,
  });

  factory Item.fromJson(Map<String, dynamic> j) => Item(
    id:       j['id']       ?? '',
    code:     j['code']     ?? '',
    name:     j['name']     ?? '',
    unit:     j['unit']     ?? '',
    category: j['category'],
  );
}

// ── Buyer ─────────────────────────────────────────────────────────────────────

class Buyer {
  final String  id;
  final String  name;
  final String  country;
  final String? email;
  final String? phone;
  final String  currency;
  final bool    isActive;
  final String? segment;

  Buyer({
    required this.id,
    required this.name,
    required this.country,
    this.email,
    this.phone,
    required this.currency,
    required this.isActive,
    this.segment,
  });

  factory Buyer.fromJson(Map<String, dynamic> j) => Buyer(
    id:       j['id']       ?? '',
    name:     j['name']     ?? '',
    country:  j['country']  ?? '',
    email:    j['email'],
    phone:    j['phone'],
    currency: j['currency'] ?? 'USD',
    isActive: j['isActive'] ?? true,
    segment:  j['segment'],
  );
}

// ── Order ─────────────────────────────────────────────────────────────────────

class Order {
  final String  id;
  final String  poNumber;
  final String  buyerId;
  final Buyer?  buyer;
  final String  status;
  final String  deliveryDate;
  final String? season;
  final String? remarks;
  final int     totalQty;
  final int     totalStyles;
  final String  createdAt;

  Order({
    required this.id,
    required this.poNumber,
    required this.buyerId,
    this.buyer,
    required this.status,
    required this.deliveryDate,
    this.season,
    this.remarks,
    required this.totalQty,
    required this.totalStyles,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:           j['id']          ?? '',
    poNumber:     j['poNumber']    ?? '',
    buyerId:      j['buyerId']     ?? '',
    buyer:        j['buyer'] != null ? Buyer.fromJson(j['buyer']) : null,
    status:       j['status']      ?? 'DRAFT',
    deliveryDate: j['deliveryDate'] ?? '',
    season:       j['season'],
    remarks:      j['remarks'],
    totalQty:     j['totalQty']    ?? 0,
    totalStyles:  j['totalStyles'] ?? 0,
    createdAt:    j['createdAt']   ?? '',
  );

  Color get statusColor {
    switch (status) {
      case 'CONFIRMED':    return const Color(0xFF1890FF);
      case 'IN_PRODUCTION': return const Color(0xFFFAAD14);
      case 'QC_PASSED':   return const Color(0xFF52C41A);
      case 'DISPATCHED':  return const Color(0xFF722ED1);
      case 'CANCELLED':   return const Color(0xFFFF4D4F);
      default:            return const Color(0xFF8C8C8C); // DRAFT
    }
  }
}

// ── Supplier ──────────────────────────────────────────────────────────────────

class Supplier {
  final String  id;
  final String  name;
  final String? contactName;
  final String? email;
  final String? phone;
  final bool    isActive;

  Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    required this.isActive,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id:          j['id']          ?? '',
    name:        j['name']        ?? '',
    contactName: j['contactName'],
    email:       j['email'],
    phone:       j['phone'],
    isActive:    j['isActive']    ?? true,
  );
}

// ── GRN ───────────────────────────────────────────────────────────────────────

class Grn {
  final String   id;
  final String   grnNumber;
  final String   supplierId;
  final Supplier? supplier;
  final String   status;
  final String   grnDate;
  final String   location;
  final String?  invoiceNo;
  final String?  remarks;
  final List<GrnLine> lines;

  Grn({
    required this.id,
    required this.grnNumber,
    required this.supplierId,
    this.supplier,
    required this.status,
    required this.grnDate,
    required this.location,
    this.invoiceNo,
    this.remarks,
    this.lines = const [],
  });

  factory Grn.fromJson(Map<String, dynamic> j) => Grn(
    id:         j['id']         ?? '',
    grnNumber:  j['grnNumber']  ?? '',
    supplierId: j['supplierId'] ?? '',
    supplier:   j['supplier'] != null ? Supplier.fromJson(j['supplier']) : null,
    status:     j['status']     ?? 'DRAFT',
    grnDate:    j['grnDate']    ?? '',
    location:   j['location']   ?? 'MAIN',
    invoiceNo:  j['invoiceNo'],
    remarks:    j['remarks'],
    lines:      (j['lines'] as List<dynamic>? ?? [])
                    .map((e) => GrnLine.fromJson(e as Map<String, dynamic>))
                    .toList(),
  );
}

class GrnLine {
  final String id;
  final String itemId;
  final Item?  item;
  final double qty;
  final double? acceptedQty;
  final String unit;
  final double rate;

  GrnLine({
    required this.id,
    required this.itemId,
    this.item,
    required this.qty,
    this.acceptedQty,
    required this.unit,
    required this.rate,
  });

  factory GrnLine.fromJson(Map<String, dynamic> j) => GrnLine(
    id:          j['id']          ?? '',
    itemId:      j['itemId']      ?? '',
    item:        j['item'] != null ? Item.fromJson(j['item']) : null,
    qty:         (j['qty']         ?? 0).toDouble(),
    acceptedQty: j['acceptedQty'] != null ? (j['acceptedQty']).toDouble() : null,
    unit:        j['unit']        ?? '',
    rate:        (j['rate']        ?? 0).toDouble(),
  );
}

// ── Inventory ─────────────────────────────────────────────────────────────────

class StockBalance {
  final String id;
  final String itemId;
  final Item?  item;
  final String location;
  final double onHand;
  final double reserved;
  final double available;

  StockBalance({
    required this.id,
    required this.itemId,
    this.item,
    required this.location,
    required this.onHand,
    required this.reserved,
    required this.available,
  });

  factory StockBalance.fromJson(Map<String, dynamic> j) => StockBalance(
    id:        j['id']        ?? '',
    itemId:    j['itemId']    ?? '',
    item:      j['item'] != null ? Item.fromJson(j['item']) : null,
    location:  j['location']  ?? 'MAIN',
    onHand:    (j['onHand']    ?? 0).toDouble(),
    reserved:  (j['reserved']  ?? 0).toDouble(),
    available: (j['available'] ?? 0).toDouble(),
  );
}

class StockLedgerEntry {
  final String  id;
  final String  itemId;
  final Item?   item;
  final String  location;
  final String  entryType;
  final double  qty;
  final double  balanceQty;
  final double? rate;
  final String? refType;
  final String? refId;
  final String? remarks;
  final String  createdAt;

  StockLedgerEntry({
    required this.id,
    required this.itemId,
    this.item,
    required this.location,
    required this.entryType,
    required this.qty,
    required this.balanceQty,
    this.rate,
    this.refType,
    this.refId,
    this.remarks,
    required this.createdAt,
  });

  factory StockLedgerEntry.fromJson(Map<String, dynamic> j) => StockLedgerEntry(
    id:         j['id']         ?? '',
    itemId:     j['itemId']     ?? '',
    item:       j['item'] != null ? Item.fromJson(j['item']) : null,
    location:   j['location']   ?? 'MAIN',
    entryType:  j['entryType']  ?? '',
    qty:        (j['qty']        ?? 0).toDouble(),
    balanceQty: (j['balanceQty'] ?? 0).toDouble(),
    rate:       j['rate'] != null ? (j['rate']).toDouble() : null,
    refType:    j['refType'],
    refId:      j['refId'],
    remarks:    j['remarks'],
    createdAt:  j['createdAt']  ?? '',
  );

  bool get isIn => qty > 0;
}
