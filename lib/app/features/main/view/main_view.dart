import 'package:easy_upi_payment/easy_upi_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/local_storage/app_storage.dart';
import '../providers/main_providers.dart';
import 'package:http/http.dart' as http;

import 'dart:async';
import 'dart:convert';


Future<String> createUPIIntent(String order_id, String order_amount) async {

  try{

    final http.Response response = await http.post(
      Uri.parse('https://jupiter.haodapayments.com/api/g5/collection'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-client-id': '--client-id--',
        'x-client-secret': '--client-secret--'
      },
      body: jsonEncode(<String, String>{
        "order_id": order_id,
        "order_amount": order_amount,
        "order_currency": "INR",
        "name": "Haoda",
        "email": "test@haodapayments.com",
        "mobile": "9876543210",
        "city": "bangalore",
        "state": "KA",
        "line1": "1/111, West street, bangalore, Karnataka"
      }),
    );



    if (response.statusCode == 200) {
      Map valueMap = json.decode(response.body);
      var json_intent = valueMap['data']['intent_link'];
      json_intent = json_intent.replaceAll("upi://pay?", "");
      return json_intent;
    } else {
      throw Exception('Failed to create upi link.');
    }

  } on Exception catch (e) {
    // Anything else that is an exception
    print('Unknown exception: $e');
    throw Exception('Failed to create upi link.');
  } catch (e) {
    // No specified type, handles all
    print('Something really unknown: $e');
    throw Exception('Failed to create upi link.');
  }

}


class MainView extends HookConsumerWidget {


  const MainView({super.key});

  static const routeName = '/main';


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStorage = ref.read(appStorageProvider);

    final amountController =
    useTextEditingController(text: appStorage.getAmount());
    final descriptionController =
    useTextEditingController(text: appStorage.getDescription());

    final formKeyRef = useRef(GlobalKey<FormState>());

    ref.listen<MainState>(
      mainStateProvider,
          (previous, next) {
        switch (next) {
          case MainState.initial:
          case MainState.loading:
            break;
          case MainState.success:
            final model =
                ref.read(mainStateProvider.notifier).transactionDetailModel;
            showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 54,
                ),
                content: Table(
                  border: TableBorder.all(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Txn Id:'),
                        ),
                        Text('  ${model?.transactionId}  '),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Response Code:'),
                        ),
                        Text('  ${model?.responseCode}  '),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Ref No:'),
                        ),
                        Text('  ${model?.approvalRefNo}  '),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Txn Ref Id:'),
                        ),
                        Text('  ${model?.transactionRefId}  '),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Amount :'),
                        ),
                        Text('  ${model?.amount}  '),
                      ],
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Okay'),
                  ),
                ],
              ),
            );
            break;
          case MainState.error:
            showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Icon(
                  Icons.cancel,
                  color: Colors.red,
                  size: 54,
                ),
                content: const Text(
                  'Transaction Failed!',
                  textAlign: TextAlign.center,
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Okay'),
                  ),
                ],
              ),
            );
            break;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Upi Payment')),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(mainStateProvider);
          return AbsorbPointer(
            absorbing: state == MainState.loading,
            child: child,
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Form(
            key: formKeyRef.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Ref ID',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter valid Ref ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final doubleValue = double.tryParse(value ?? '');
                    if (value == null || value.isEmpty || doubleValue == null) {
                      return 'Please enter valid amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 36),
                Consumer(
                  builder: (context, ref, child) {
                    final state = ref.watch(mainStateProvider);
                    switch (state) {
                      case MainState.initial:
                      case MainState.success:
                      case MainState.error:
                        return child!;
                      case MainState.loading:
                        return const Center(child: CircularProgressIndicator());
                    }
                  },
                  child: ElevatedButton(
                    onPressed: () async{
                      if (formKeyRef.value.currentState!.validate()) {

                        var json_intent = await createUPIIntent(descriptionController.text,amountController.text);

                        List<List<String>> asdf = json_intent.split('&').map((e) => e.split("=")).toList();

                        var ver = '';
                        var mode= '';
                        var am= '';
                        var mam= '';
                        var cu= '';
                        var pa= '';
                        var pn= '';
                        var mc= '';
                        var tr= '';
                        var tn= '';
                        asdf.forEach((a) =>
                        {
                          if(a[0] == 'ver'){
                            ver = a[1]
                          },
                          if(a[0] == 'mode'){
                            mode = a[1]
                          },
                          if(a[0] == 'am'){
                            am = a[1]
                          },
                          if(a[0] == 'mam'){
                            mam = a[1]
                          },
                          if(a[0] == 'cu'){
                            cu = a[1]
                          },
                          if(a[0] == 'pa'){
                            pa = a[1]
                          },
                          if(a[0] == 'pn'){
                            pn = a[1]
                          },
                          if(a[0] == 'mc'){
                            mc = a[1]
                          },
                          if(a[0] == 'tr'){
                            tr = a[1]
                          },
                          if(a[0] == 'tn'){
                            tn = a[1]
                          }

                        }
                        );


                        ref.read(mainStateProvider.notifier).startPayment(
                          EasyUpiPaymentModel(
                              payeeVpa: pa,
                              payeeName: pn,
                              payeeMerchantCode: mc,
                              amount: double.parse(amountController.text),
                              description: tr,
                              transactionId: tn,
                              transactionRefId: tr
                          ),

                        );
                      }
                    },
                    style: ButtonStyle(
                      fixedSize:
                      MaterialStateProperty.all(const Size.fromHeight(42)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50), // Adjust the radius as needed
                        ),
                      ),
                    ),
                    child: const Text('Pay Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}