import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../socket_manager.dart';

class MessageBloc {
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _messageController.stream;

  // List<Message> _allMessages = <Message>[];
  LinkedHashMap<String, Message> _allMessages = new LinkedHashMap();

  Map<String, List<Message>> _reactions = new Map();

  LinkedHashMap<String, Message> get messages => _allMessages;

  Map<String, List<Message>> get reactions => _reactions;

  Chat _currentChat;

  Chat get currentChat => _currentChat;

  String get firstSentMessage {
    for (Message message in _allMessages.values) {
      if (message.isFromMe) {
        return message.guid;
      }
    }
    return "no sent message found";
  }

  MessageBloc(Chat chat) {
    _currentChat = chat;
    // getMessages();
    NewMessageManager().stream.listen((Map<String, dynamic> event) {
      if (_messageController.isClosed) return;
      if (event.containsKey(_currentChat.guid)) {
        //if there even is a chat specified in the newmessagemanager update
        if (event[_currentChat.guid] == null) {
          //if no message is specified in the newmessagemanager update
          getMessages();
        } else {
          if (event.containsKey("oldGuid")) {
            debugPrint("is an update " + event["oldGuid"]);
            if (_allMessages.containsKey(event["oldGuid"])) {
              List<Message> values = _allMessages.values.toList();
              List<String> keys = _allMessages.keys.toList();
              for (int i = 0; i < keys.length; i++) {
                if (keys[i] == event["oldGuid"]) {
                  keys[i] = (event[_currentChat.guid] as Message).guid;
                  values[i] = event[_currentChat.guid];
                  break;
                }
              }
              _allMessages = LinkedHashMap<String, Message>.from(
                  LinkedHashMap.fromIterables(keys, values));
              debugPrint("_allMessages updated, now contains " +
                  event[_currentChat.guid].guid);
              if (!_messageController.isClosed)
                _messageController.sink.add({
                  "messages": _allMessages,
                  "update": event[_currentChat.guid],
                  "index": null
                });
            } else {
              debugPrint("could not find existing message");
            }
          } else {
            //if there is a specific message to insert
            insert(event[_currentChat.guid],
                sentFromThisClient: event.containsKey("sentFromThisClient")
                    ? event["sentFromThisClient"]
                    : false);
          }
        }
      } else if (event.keys.first == null) {
        //if there is no chat specified in the newmessagemanager update
        getMessages();
      }
    });
  }

  void insert(Message message, {bool sentFromThisClient = false}) {
    int index = 0;
    if (_allMessages.length == 0) {
      _allMessages.addAll({message.guid: message});
      if (!_messageController.isClosed)
        _messageController.sink.add({
          "messages": _allMessages,
          "insert": message,
          "index": index,
          "sentFromThisClient": sentFromThisClient
        });
      return;
    }
    List<Message> messages = _allMessages.values.toList();
    for (int i = 0; i < messages.length; i++) {
      //if _allMessages[i] dateCreated is earlier than the new message, insert at that index
      if (messages[i].dateCreated.compareTo(message.dateCreated) < 0) {
        _allMessages =
            linkedHashMapInsert(_allMessages, index, message.guid, message);
        index = i;
        break;
      }
    }
    if (!_messageController.isClosed)
      _messageController.sink.add({
        "messages": _allMessages,
        "insert": message,
        "index": index,
        "sentFromThisClient": sentFromThisClient
      });
  }

  LinkedHashMap linkedHashMapInsert(map, int index, key, value) {
    List keys = map.keys.toList();
    List values = map.values.toList();
    keys.insert(index, key);
    values.insert(index, value);
    debugPrint("insert into hashmap");
    return LinkedHashMap<String, Message>.from(
        LinkedHashMap.fromIterables(keys, values));
  }

  Future<LinkedHashMap<String, Message>> getMessages() async {
    List<Message> messages = await Chat.getMessages(_currentChat);
    messages.forEach((element) {
      _allMessages.addAll({element.guid: element});
    });
    if (!_messageController.isClosed)
      _messageController.sink.add({"messages": _allMessages, "insert": null});
    getReactions(0);
    return _allMessages;
  }

  Future loadMessageChunk(int offset) async {
    debugPrint("loading older messages");
    Completer completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages =
          await Chat.getMessages(_currentChat, offset: offset);
      if (messages.length == 0) {
        debugPrint("messages length is 0, fetching from server");
        Map<String, dynamic> params = Map();
        params["identifier"] = _currentChat.guid;
        params["limit"] = 25;
        params["offset"] = offset;
        params["withBlurhash"] = true;
        params["where"] = [
          {"statement": "message.service = 'iMessage'", "args": null}
        ];

        SocketManager()
            .socket
            .sendMessage("get-chat-messages", jsonEncode(params), (data) async {
          List messages = jsonDecode(data)["data"];
          if (messages.length == 0) {
            completer.complete();
            return;
          }
          debugPrint("got messages");
          List<Message> _messages =
              await MessageHelper.bulkAddMessages(_currentChat, messages);
          _messages.forEach((element) {
            _allMessages.addAll({element.guid: element});
          });
          // _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
          if (!_messageController.isClosed)
            _messageController.sink
                .add({"messages": _allMessages, "insert": null});
          completer.complete();
          await getReactions(offset);
        });
      } else {
        // debugPrint("loading more messages from sql " +);
        messages.forEach((element) {
          _allMessages.addAll({element.guid: element});
        });
        // _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
        if (!_messageController.isClosed)
          _messageController.sink
              .add({"messages": _allMessages, "insert": null});
        completer.complete();
        await getReactions(offset);
      }
    } else {
      completer.completeError("chat not found");
    }
    return completer.future;
  }

  Future<void> getReactions(int offset) async {
    List<Message> reactionsResult = await Chat.getMessages(_currentChat,
        reactionsOnly: true, offset: offset);
    _reactions = new Map();
    reactionsResult.forEach((element) {
      if (element.associatedMessageGuid != null) {
        // debugPrint(element.handle.toString());
        String guid = element.associatedMessageGuid
            .substring(element.associatedMessageGuid.indexOf("/") + 1);

        if (!_reactions.containsKey(guid)) _reactions[guid] = <Message>[];
        _reactions[guid].add(element);
      }
    });
    if (!_messageController.isClosed)
      _messageController.sink.add({"messages": _allMessages, "insert": null});
  }

  void dispose() {
    _allMessages = new LinkedHashMap();
    debugPrint("disposed all messages");
    _messageController.close();
  }
}
