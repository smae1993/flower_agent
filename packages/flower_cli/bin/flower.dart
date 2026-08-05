import 'dart:io';

import 'package:flower_agent/flower_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await FlowerCli().run(arguments);
}
