// GENERATED FILE — DO NOT EDIT BY HAND
// Run: bash codegen.sh
// Source: openapi.json (auto-exported from NestJS backend)

// ignore_for_file: unnecessary_null_comparison

class RegisterDto {
  final String name;
  final String email;
  final String password;
  final String tenantId;
  final List<String> roles;

  const RegisterDto({
    required this.name,
    required this.email,
    required this.password,
    required this.tenantId,
    required this.roles,
  });

  factory RegisterDto.fromJson(Map<String, dynamic> j) => RegisterDto(
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
    password: j['password'] as String? ?? '',
    tenantId: j['tenantId'] as String? ?? '',
    roles: (j['roles'] as List<dynamic>? ?? []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
      'name': name,
      'email': email,
      'password': password,
      'tenantId': tenantId,
      'roles': roles,
  };
}

class LoginDto {
  final String email;
  final String password;

  const LoginDto({
    required this.email,
    required this.password,
  });

  factory LoginDto.fromJson(Map<String, dynamic> j) => LoginDto(
    email: j['email'] as String? ?? '',
    password: j['password'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'email': email,
      'password': password,
  };
}

class VerifyOtpDto {
  final String tempToken;
  final String otp;

  const VerifyOtpDto({
    required this.tempToken,
    required this.otp,
  });

  factory VerifyOtpDto.fromJson(Map<String, dynamic> j) => VerifyOtpDto(
    tempToken: j['tempToken'] as String? ?? '',
    otp: j['otp'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'tempToken': tempToken,
      'otp': otp,
  };
}

class ResendOtpDto {
  final String tempToken;

  const ResendOtpDto({
    required this.tempToken,
  });

  factory ResendOtpDto.fromJson(Map<String, dynamic> j) => ResendOtpDto(
    tempToken: j['tempToken'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'tempToken': tempToken,
  };
}

class RefreshTokenDto {
  final String refreshToken;

  const RefreshTokenDto({
    required this.refreshToken,
  });

  factory RefreshTokenDto.fromJson(Map<String, dynamic> j) => RefreshTokenDto(
    refreshToken: j['refreshToken'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'refreshToken': refreshToken,
  };
}

class ForgotPasswordDto {
  final String email;

  const ForgotPasswordDto({
    required this.email,
  });

  factory ForgotPasswordDto.fromJson(Map<String, dynamic> j) => ForgotPasswordDto(
    email: j['email'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'email': email,
  };
}

class ResetPasswordDto {
  final String token;
  final String newPassword;

  const ResetPasswordDto({
    required this.token,
    required this.newPassword,
  });

  factory ResetPasswordDto.fromJson(Map<String, dynamic> j) => ResetPasswordDto(
    token: j['token'] as String? ?? '',
    newPassword: j['newPassword'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'token': token,
      'newPassword': newPassword,
  };
}

class ChangePasswordDto {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordDto({
    required this.currentPassword,
    required this.newPassword,
  });

  factory ChangePasswordDto.fromJson(Map<String, dynamic> j) => ChangePasswordDto(
    currentPassword: j['currentPassword'] as String? ?? '',
    newPassword: j['newPassword'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
  };
}

class CreateBuyerDto {
  final String name;
  final String country;
  final String? email;
  final String? phone;
  final String? currency;
  final String? address;
  final String? paymentTerms;
  final double? creditLimit;
  final double? creditDays;
  final String? taxId;
  final String? segment;
  final String? website;

  const CreateBuyerDto({
    required this.name,
    required this.country,
    this.email,
    this.phone,
    this.currency,
    this.address,
    this.paymentTerms,
    this.creditLimit,
    this.creditDays,
    this.taxId,
    this.segment,
    this.website,
  });

  factory CreateBuyerDto.fromJson(Map<String, dynamic> j) => CreateBuyerDto(
    name: j['name'] as String? ?? '',
    country: j['country'] as String? ?? '',
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    currency: j['currency'] as String?,
    address: j['address'] as String?,
    paymentTerms: j['paymentTerms'] as String?,
    creditLimit: (j['creditLimit'] as num?)?.toDouble(),
    creditDays: (j['creditDays'] as num?)?.toDouble(),
    taxId: j['taxId'] as String?,
    segment: j['segment'] as String?,
    website: j['website'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'name': name,
      'country': country,
      'email': email,
      'phone': phone,
      'currency': currency,
      'address': address,
      'paymentTerms': paymentTerms,
      'creditLimit': creditLimit,
      'creditDays': creditDays,
      'taxId': taxId,
      'segment': segment,
      'website': website,
  };
}

class UpdateBuyerDto {
  final String? name;
  final String? country;
  final String? email;
  final String? phone;
  final String? currency;
  final String? address;
  final bool? isActive;
  final String? paymentTerms;
  final double? creditLimit;
  final double? creditDays;
  final String? taxId;
  final String? segment;
  final String? website;

  const UpdateBuyerDto({
    this.name,
    this.country,
    this.email,
    this.phone,
    this.currency,
    this.address,
    this.isActive,
    this.paymentTerms,
    this.creditLimit,
    this.creditDays,
    this.taxId,
    this.segment,
    this.website,
  });

  factory UpdateBuyerDto.fromJson(Map<String, dynamic> j) => UpdateBuyerDto(
    name: j['name'] as String?,
    country: j['country'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    currency: j['currency'] as String?,
    address: j['address'] as String?,
    isActive: j['isActive'] as bool?,
    paymentTerms: j['paymentTerms'] as String?,
    creditLimit: (j['creditLimit'] as num?)?.toDouble(),
    creditDays: (j['creditDays'] as num?)?.toDouble(),
    taxId: j['taxId'] as String?,
    segment: j['segment'] as String?,
    website: j['website'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'name': name,
      'country': country,
      'email': email,
      'phone': phone,
      'currency': currency,
      'address': address,
      'isActive': isActive,
      'paymentTerms': paymentTerms,
      'creditLimit': creditLimit,
      'creditDays': creditDays,
      'taxId': taxId,
      'segment': segment,
      'website': website,
  };
}

class CreateSupplierDto {
  final String name;
  final String? gstin;
  final String? email;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final List<String> services;
  final String? pan;
  final String? paymentTerms;
  final double? creditDays;
  final String? bankAccount;
  final String? bankIfsc;
  final String? bankName;
  final String? website;

  const CreateSupplierDto({
    required this.name,
    this.gstin,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
    required this.services,
    this.pan,
    this.paymentTerms,
    this.creditDays,
    this.bankAccount,
    this.bankIfsc,
    this.bankName,
    this.website,
  });

  factory CreateSupplierDto.fromJson(Map<String, dynamic> j) => CreateSupplierDto(
    name: j['name'] as String? ?? '',
    gstin: j['gstin'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    contactPerson: j['contactPerson'] as String?,
    services: (j['services'] as List<dynamic>? ?? []).cast<String>(),
    pan: j['pan'] as String?,
    paymentTerms: j['paymentTerms'] as String?,
    creditDays: (j['creditDays'] as num?)?.toDouble(),
    bankAccount: j['bankAccount'] as String?,
    bankIfsc: j['bankIfsc'] as String?,
    bankName: j['bankName'] as String?,
    website: j['website'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'name': name,
      'gstin': gstin,
      'email': email,
      'phone': phone,
      'address': address,
      'contactPerson': contactPerson,
      'services': services,
      'pan': pan,
      'paymentTerms': paymentTerms,
      'creditDays': creditDays,
      'bankAccount': bankAccount,
      'bankIfsc': bankIfsc,
      'bankName': bankName,
      'website': website,
  };
}

class UpdateSupplierDto {
  final String? name;
  final String? gstin;
  final String? email;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final List<String> services;
  final bool? isActive;
  final String? pan;
  final String? paymentTerms;
  final double? creditDays;
  final String? bankAccount;
  final String? bankIfsc;
  final String? bankName;
  final String? website;

  const UpdateSupplierDto({
    this.name,
    this.gstin,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
    required this.services,
    this.isActive,
    this.pan,
    this.paymentTerms,
    this.creditDays,
    this.bankAccount,
    this.bankIfsc,
    this.bankName,
    this.website,
  });

  factory UpdateSupplierDto.fromJson(Map<String, dynamic> j) => UpdateSupplierDto(
    name: j['name'] as String?,
    gstin: j['gstin'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    contactPerson: j['contactPerson'] as String?,
    services: (j['services'] as List<dynamic>? ?? []).cast<String>(),
    isActive: j['isActive'] as bool?,
    pan: j['pan'] as String?,
    paymentTerms: j['paymentTerms'] as String?,
    creditDays: (j['creditDays'] as num?)?.toDouble(),
    bankAccount: j['bankAccount'] as String?,
    bankIfsc: j['bankIfsc'] as String?,
    bankName: j['bankName'] as String?,
    website: j['website'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'name': name,
      'gstin': gstin,
      'email': email,
      'phone': phone,
      'address': address,
      'contactPerson': contactPerson,
      'services': services,
      'isActive': isActive,
      'pan': pan,
      'paymentTerms': paymentTerms,
      'creditDays': creditDays,
      'bankAccount': bankAccount,
      'bankIfsc': bankIfsc,
      'bankName': bankName,
      'website': website,
  };
}

class CreatePoLineDto {
  final String itemId;
  final double qty;
  final String unit;
  final double rate;
  final String? description;
  final String? hsnCode;
  final double? gstPct;

  const CreatePoLineDto({
    required this.itemId,
    required this.qty,
    required this.unit,
    required this.rate,
    this.description,
    this.hsnCode,
    this.gstPct,
  });

  factory CreatePoLineDto.fromJson(Map<String, dynamic> j) => CreatePoLineDto(
    itemId: j['itemId'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    unit: j['unit'] as String? ?? '',
    rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
    description: j['description'] as String?,
    hsnCode: j['hsnCode'] as String?,
    gstPct: (j['gstPct'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'qty': qty,
      'unit': unit,
      'rate': rate,
      'description': description,
      'hsnCode': hsnCode,
      'gstPct': gstPct,
  };
}

class CreatePurchaseOrderDto {
  final String supplierId;
  final String poDate;
  final String expectedDate;
  final String? remarks;
  final List<CreatePoLineDto> lines;

  const CreatePurchaseOrderDto({
    required this.supplierId,
    required this.poDate,
    required this.expectedDate,
    this.remarks,
    required this.lines,
  });

  factory CreatePurchaseOrderDto.fromJson(Map<String, dynamic> j) => CreatePurchaseOrderDto(
    supplierId: j['supplierId'] as String? ?? '',
    poDate: j['poDate'] as String? ?? '',
    expectedDate: j['expectedDate'] as String? ?? '',
    remarks: j['remarks'] as String?,
    lines: (j['lines'] as List<dynamic>? ?? [])
        .map((e) => CreatePoLineDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
      'supplierId': supplierId,
      'poDate': poDate,
      'expectedDate': expectedDate,
      'remarks': remarks,
      'lines': lines.map((e) => e.toJson()).toList(),
  };
}

class OrderLineDto {
  final String styleCode;
  final String itemId;
  final String? colour;
  final double qty;
  final dynamic sizesJson;
  final double? unitPrice;
  final String? currency;

  const OrderLineDto({
    required this.styleCode,
    required this.itemId,
    this.colour,
    required this.qty,
    required this.sizesJson,
    this.unitPrice,
    this.currency,
  });

  factory OrderLineDto.fromJson(Map<String, dynamic> j) => OrderLineDto(
    styleCode: j['styleCode'] as String? ?? '',
    itemId: j['itemId'] as String? ?? '',
    colour: j['colour'] as String?,
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    sizesJson: j['sizesJson'] as dynamic,
    unitPrice: (j['unitPrice'] as num?)?.toDouble(),
    currency: j['currency'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'styleCode': styleCode,
      'itemId': itemId,
      'colour': colour,
      'qty': qty,
      'sizesJson': sizesJson,
      'unitPrice': unitPrice,
      'currency': currency,
  };
}

class CreateOrderDto {
  final String buyerId;
  final String poNumber;
  final String deliveryDate;
  final String? season;
  final String? remarks;
  final List<OrderLineDto> lines;

  const CreateOrderDto({
    required this.buyerId,
    required this.poNumber,
    required this.deliveryDate,
    this.season,
    this.remarks,
    required this.lines,
  });

  factory CreateOrderDto.fromJson(Map<String, dynamic> j) => CreateOrderDto(
    buyerId: j['buyerId'] as String? ?? '',
    poNumber: j['poNumber'] as String? ?? '',
    deliveryDate: j['deliveryDate'] as String? ?? '',
    season: j['season'] as String?,
    remarks: j['remarks'] as String?,
    lines: (j['lines'] as List<dynamic>? ?? [])
        .map((e) => OrderLineDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
      'buyerId': buyerId,
      'poNumber': poNumber,
      'deliveryDate': deliveryDate,
      'season': season,
      'remarks': remarks,
      'lines': lines.map((e) => e.toJson()).toList(),
  };
}

class UpdateOrderDto {
  final String? buyerId;
  final String? poNumber;
  final String? deliveryDate;
  final String? season;
  final String? remarks;
  final List<OrderLineDto> lines;
  final String? reason;

  const UpdateOrderDto({
    this.buyerId,
    this.poNumber,
    this.deliveryDate,
    this.season,
    this.remarks,
    required this.lines,
    this.reason,
  });

  factory UpdateOrderDto.fromJson(Map<String, dynamic> j) => UpdateOrderDto(
    buyerId: j['buyerId'] as String?,
    poNumber: j['poNumber'] as String?,
    deliveryDate: j['deliveryDate'] as String?,
    season: j['season'] as String?,
    remarks: j['remarks'] as String?,
    lines: (j['lines'] as List<dynamic>? ?? [])
        .map((e) => OrderLineDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    reason: j['reason'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'buyerId': buyerId,
      'poNumber': poNumber,
      'deliveryDate': deliveryDate,
      'season': season,
      'remarks': remarks,
      'lines': lines.map((e) => e.toJson()).toList(),
      'reason': reason,
  };
}

class BomLineDto {
  final String rawItemId;
  final double qty;
  final String unit;
  final double? wastagePct;
  final String? remarks;

  const BomLineDto({
    required this.rawItemId,
    required this.qty,
    required this.unit,
    this.wastagePct,
    this.remarks,
  });

  factory BomLineDto.fromJson(Map<String, dynamic> j) => BomLineDto(
    rawItemId: j['rawItemId'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    unit: j['unit'] as String? ?? '',
    wastagePct: (j['wastagePct'] as num?)?.toDouble(),
    remarks: j['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'rawItemId': rawItemId,
      'qty': qty,
      'unit': unit,
      'wastagePct': wastagePct,
      'remarks': remarks,
  };
}

class CreateBomDto {
  final String itemId;
  final String? styleCode;
  final String? remarks;
  final List<BomLineDto> lines;

  const CreateBomDto({
    required this.itemId,
    this.styleCode,
    this.remarks,
    required this.lines,
  });

  factory CreateBomDto.fromJson(Map<String, dynamic> j) => CreateBomDto(
    itemId: j['itemId'] as String? ?? '',
    styleCode: j['styleCode'] as String?,
    remarks: j['remarks'] as String?,
    lines: (j['lines'] as List<dynamic>? ?? [])
        .map((e) => BomLineDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'styleCode': styleCode,
      'remarks': remarks,
      'lines': lines.map((e) => e.toJson()).toList(),
  };
}

class StockAdjustmentDto {
  final String itemId;
  final String? location;
  final double qty;
  final String reason;
  final String? externalRef;

  const StockAdjustmentDto({
    required this.itemId,
    this.location,
    required this.qty,
    required this.reason,
    this.externalRef,
  });

  factory StockAdjustmentDto.fromJson(Map<String, dynamic> j) => StockAdjustmentDto(
    itemId: j['itemId'] as String? ?? '',
    location: j['location'] as String?,
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    reason: j['reason'] as String? ?? '',
    externalRef: j['externalRef'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'location': location,
      'qty': qty,
      'reason': reason,
      'externalRef': externalRef,
  };
}

class IssueToProductionDto {
  final String itemId;
  final String? location;
  final double qty;
  final String? orderId;
  final String? remarks;

  const IssueToProductionDto({
    required this.itemId,
    this.location,
    required this.qty,
    this.orderId,
    this.remarks,
  });

  factory IssueToProductionDto.fromJson(Map<String, dynamic> j) => IssueToProductionDto(
    itemId: j['itemId'] as String? ?? '',
    location: j['location'] as String?,
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    orderId: j['orderId'] as String?,
    remarks: j['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'location': location,
      'qty': qty,
      'orderId': orderId,
      'remarks': remarks,
  };
}

class ReturnFromProductionDto {
  final String itemId;
  final String? location;
  final double qty;
  final String? orderId;
  final String? remarks;

  const ReturnFromProductionDto({
    required this.itemId,
    this.location,
    required this.qty,
    this.orderId,
    this.remarks,
  });

  factory ReturnFromProductionDto.fromJson(Map<String, dynamic> j) => ReturnFromProductionDto(
    itemId: j['itemId'] as String? ?? '',
    location: j['location'] as String?,
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    orderId: j['orderId'] as String?,
    remarks: j['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'location': location,
      'qty': qty,
      'orderId': orderId,
      'remarks': remarks,
  };
}

class TransferStockDto {
  final String itemId;
  final String fromLocation;
  final String toLocation;
  final double qty;
  final String? remarks;

  const TransferStockDto({
    required this.itemId,
    required this.fromLocation,
    required this.toLocation,
    required this.qty,
    this.remarks,
  });

  factory TransferStockDto.fromJson(Map<String, dynamic> j) => TransferStockDto(
    itemId: j['itemId'] as String? ?? '',
    fromLocation: j['fromLocation'] as String? ?? '',
    toLocation: j['toLocation'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    remarks: j['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'qty': qty,
      'remarks': remarks,
  };
}

class SetOpeningStockDto {
  final String itemId;
  final String? location;
  final double qty;
  final double? rate;
  final String? remarks;

  const SetOpeningStockDto({
    required this.itemId,
    this.location,
    required this.qty,
    this.rate,
    this.remarks,
  });

  factory SetOpeningStockDto.fromJson(Map<String, dynamic> j) => SetOpeningStockDto(
    itemId: j['itemId'] as String? ?? '',
    location: j['location'] as String?,
    qty: (j['qty'] as num?)?.toDouble() ?? 0.0,
    rate: (j['rate'] as num?)?.toDouble(),
    remarks: j['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'location': location,
      'qty': qty,
      'rate': rate,
      'remarks': remarks,
  };
}

class RebuildBalanceDto {
  final String itemId;
  final String location;

  const RebuildBalanceDto({
    required this.itemId,
    required this.location,
  });

  factory RebuildBalanceDto.fromJson(Map<String, dynamic> j) => RebuildBalanceDto(
    itemId: j['itemId'] as String? ?? '',
    location: j['location'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
      'itemId': itemId,
      'location': location,
  };
}
