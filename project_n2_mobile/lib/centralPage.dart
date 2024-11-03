import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CentralPage extends StatefulWidget {
  @override
  _CentralPageState createState() => _CentralPageState();
}

class _CentralPageState extends State<CentralPage> {
  final List<Map<String, dynamic>> transactions = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  double _calcularSaldo() {
    double saldo = 0.0;
    for (var transaction in transactions) {
      if (transaction['tipo'] == 'Entrada') {
        saldo += transaction['valor'];
      } else if (transaction['tipo'] == 'Custo') {
        saldo -= transaction['valor'];
      }
    }
    return saldo;
  }


  // Função para carregar transações do Firestore
  Future<void> _loadTransactions() async {
    QuerySnapshot snapshot = await _firestore.collection('transacoes').get();
    setState(() {
      transactions.clear();
      for (var doc in snapshot.docs) {
        transactions.add(doc.data() as Map<String, dynamic>);
      }
    });
  }

  // Função para abrir o modal de adição/edição de transação
  void _openTransactionModal({Map<String, dynamic>? transaction, String? docId}) {
    String? tipo = transaction?['tipo'];
    String? titulo = transaction?['titulo'];
    String? valor = transaction != null ? transaction['valor'].toString() : null;

    showDialog(
      context: context,
      builder: (context) {
        String? selectedTipo = tipo; // O tipo selecionado no modal
        return AlertDialog(
          title: Text(transaction == null ? 'Adicionar Transação' : 'Editar Transação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTipo,
                decoration: InputDecoration(labelText: 'Tipo de Transação'),
                items: [
                  DropdownMenuItem(value: 'Custo', child: Text('Custo (-)')),
                  DropdownMenuItem(value: 'Entrada', child: Text('Entrada (+)')),
                ],
                onChanged: (value) {
                  selectedTipo = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Título'),
                controller: TextEditingController(text: titulo),
                onChanged: (value) {
                  titulo = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Valor'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: valor),
                onChanged: (value) {
                  valor = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTipo != null && titulo != null && valor != null) {
                  final transactionData = {
                    'tipo': selectedTipo,
                    'titulo': titulo,
                    'valor': double.tryParse(valor!) ?? 0.0,
                  };

                  if (docId == null) {
                    // Adiciona nova transação
                    DocumentReference docRef = await _firestore.collection('transacoes').add(transactionData);
                    setState(() {
                      transactions.add({...transactionData, 'id': docRef.id}); // Adiciona o ID gerado
                    });
                  } else {
                    // Atualiza transação existente
                    await _firestore.collection('transacoes').doc(docId).update(transactionData);
                    setState(() {
                      final index = transactions.indexWhere((t) => t['id'] == docId);
                      transactions[index] = {...transactionData, 'id': docId}; // Atualiza a transação existente
                    });
                  }

                  Navigator.of(context).pop();
                }
              },
              child: Text(transaction == null ? 'Salvar' : 'Atualizar'),
            )
          ],
        );
      },
    );
  }

  void _deleteTransaction(String docId) async {
    await _firestore.collection('transacoes').doc(docId).delete();
    setState(() {
      transactions.removeWhere((transaction) => transaction['id'] == docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        elevation: 0,
        centerTitle: true,
        title:
        Column(
          children: [
            Icon(
              Icons.attach_money,
              size: 40,
              color: Colors.green,
            ),
          ],
        )
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Saldo: R\$ ${_calcularSaldo().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isCusto = transaction['tipo'] == 'Custo';
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        isCusto ? Icons.remove_circle : Icons.add_circle,
                        color: isCusto ? Colors.red : Colors.green,
                      ),
                      title: Text(transaction['titulo']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isCusto ? '-' : '+'} R\$ ${transaction['valor'].toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isCusto ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _openTransactionModal(
                                transaction: transaction,
                                docId: transaction['id'],
                              ); // Editar transação
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTransaction(transaction['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionModal(),
        child: Icon(Icons.add),
        backgroundColor: Color(0xFFAAF0D1),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
