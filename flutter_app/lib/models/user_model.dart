class UserModel {
  final String id;
  final String name;
  final String email;
  final String partnerCode;
  final String? partnerId;
  final String? incomingRequestFromId;
  final String? pendingRequestToId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.partnerCode,
    this.partnerId,
    this.incomingRequestFromId,
    this.pendingRequestToId,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      partnerCode: data['partnerCode'] ?? '',
      partnerId: data['partnerId'],
      incomingRequestFromId: data['incomingRequestFromId'],
      pendingRequestToId: data['pendingRequestToId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'partnerCode': partnerCode,
      'partnerId': partnerId,
      'incomingRequestFromId': incomingRequestFromId,
      'pendingRequestToId': pendingRequestToId,
    };
  }
}
