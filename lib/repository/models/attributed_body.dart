class AttributedBody {
  AttributedBody({
    required this.string,
    required this.runs,
  });

  final String string;
  final List<Run> runs;

  factory AttributedBody.fromMap(Map<String, dynamic> json) => AttributedBody(
    string: json["string"],
    runs: json["runs"] == null ? [] : List<Run>.from(json["runs"].map((x) => Run.fromMap(x))),
  );

  Map<String, dynamic> toMap() => {
    "string": string,
    "runs": List<Map<String, dynamic>>.from(runs.map((x) => x.toMap())),
  };
}

class Run {
  Run({
    required this.range,
    this.attributes,
  });

  final List<int> range;
  final Attributes? attributes;

  factory Run.fromMap(Map<String, dynamic> json) => Run(
    range: json["range"] == null ? [] : List<int>.from(json["range"].map((x) => x)),
    attributes: json["attributes"] == null ? null : Attributes.fromMap(json["attributes"]),
  );

  Map<String, dynamic> toMap() => {
    "range": range,
    "attributes": attributes?.toMap(),
  };
}

class Attributes {
  Attributes({
    required this.messagePart,
    this.attachmentGuid,
    this.mention,
  });

  final int messagePart;
  final String? attachmentGuid;
  final String? mention;

  factory Attributes.fromMap(Map<String, dynamic> json) => Attributes(
    messagePart: json["__kIMMessagePartAttributeName"],
    attachmentGuid: json["__kIMFileTransferGUIDAttributeName"],
    mention: json["__kIMMentionConfirmedMention"],
  );

  Map<String, dynamic> toMap() => {
    "__kIMMessagePartAttributeName": messagePart,
    "__kIMFileTransferGUIDAttributeName": attachmentGuid,
    "__kIMMentionConfirmedMention": mention,
  };
}
