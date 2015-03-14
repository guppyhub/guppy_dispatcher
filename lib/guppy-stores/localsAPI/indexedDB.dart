library guppy.stores.indexeddb;


//All stores must include this guppy librarys
import 'package:guppy/guppy-stores/guppy-stores.dart';
import 'dart:async';

//Add here specifics librarys for the store
import 'package:logging/logging.dart';
import 'dart:html';
import 'dart:indexed_db' as idb;

//
class GuppyIndexedDB extends GuppyAbstractLocalStorage{
  final Logger log = new Logger('GuppyIndexedDB');

  String iDBName;
  bool isInitialized = false;

  //Link between type and objectStore
  Map<String, GuppyConfigResource> objectsStores = new Map();
  List<GuppyResource> resources;
  idb.Database _idb;

  GuppyConfig config;
  Map storeConfig;

  //GuppyIndexedDB _indexedDB = new GuppyIndexedDB();

  /****************************************************************************************************\
  * API methods
  \****************************************************************************************************/
  GuppyIndexedDB(name, this.storeConfig) : super(name){
    this.log.finest('Instanciation de Guppy');
  }

  Future init(resources){
    log.finest('start of indexedDB initialization');
    this.resources = resources;

    this.iDBName = this.config.getLocalStoreConf()['dbName'];
    this.config.getResources().forEach((k, v){
      objectsStores[k] = new GuppyConfigResource(k);
    });
    //timer = new Timer.periodic(new Duration(seconds:10), checkUpdates);

    this.resources.forEach((r){

    });


    return window.indexedDB.open(
        this.iDBName,
        version: 1,
        onUpgradeNeeded: _initializeDatabase)
    .then((db){
      this._idb = db;
      this.isInitialized = true;
      log.finest('indexedDB initialized');
    });
  }



/**
 * Initialisation de la base de donnees, appellee en cas de premiere creation ou de montee de version
 */
  void _initializeDatabase(idb.VersionChangeEvent e) {
    log.finest('Versions : ${e.oldVersion} => ${e.newVersion}');
    //log.finest('_initializeDatabase');
    idb.Database db = (e.target as idb.Request).result;

    if(e.oldVersion == 0 ){
      //Premiere creation de la base
      log.finest('There is ${objectsStores.length} to Initialize');
      objectsStores.forEach((k, GuppyConfigResource o){
        log.finest('Initialization of ObjectStore : ${o.name}');
        idb.ObjectStore t = db.createObjectStore(o.name , autoIncrement: o.isAutoIncrementKey);
        if(o.indexes != null){
          o.indexes.forEach((Map i) => t.createIndex(i['name'], i['keyPath'], unique: i['unique']));
        }
      });
    } else if(e.oldVersion != e.newVersion ){
      //Montee de version de la base
      log.finest('difference de versions : ${e.oldVersion} => ${e.newVersion}');
      //TODO Realiser la montee de version
    }
  }

  Future<Map<String, String>> get(String type, String id){
    log.finest('_getOneFromDB / $type / $id');

    GuppyConfigResource objStore = objectsStores[type];
    if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

    var transaction = this._idb.transaction(objStore.name , 'readwrite');
    var objectStore = transaction.objectStore(objStore.name);

    return objectStore.getObject(id).then((v){return v;});

    //return transaction.completed.then((v){return v.;});
  }

  executeIfOpen(Future f){
    if(isInitialized == false){
      Future f = new Future.delayed(new Duration(seconds:4));
      return f.then((r){
        return f;
      });
    } else {
      return f;
    }
  }

  /**
   *
   */
  Future<List<Map<String,String>>> list(String type){
    log.finest('_getAllFromDB / $type');

    GuppyConfigResource objStore = objectsStores[type];
    if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

    var transaction = this._idb.transaction(objStore.name, 'readonly');
    var objectStore = transaction.objectStore(objStore.name);

    var cursors = objectStore.openCursor(autoAdvance: true);
    List<Map<String, String>> l = new List<Map<String, String>>();

    return cursors.forEach((v) => l.add(v.value)).then((_){
      return l;
    });
  }

  /**
   *
   */
  Future<Map<String, String>> save(String type, Map<String, String> object, [String id]) {
    log.finest('addInDB $type / $id / $object');

    GuppyConfigResource objStore = objectsStores[type];
    if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

    var transaction = this._idb.transaction(objStore.name , 'readwrite');
    var objectStore = transaction.objectStore(objStore.name);

    objectStore.add(object, id);

    return transaction.completed.then((_) {
      return id;
    });
  }

  /**
   *
   */
  Future<Map<String, String>> update(String type, Map<String, String> object, String id) {
    log.finest('_updateInDb $type / $id / $object');

    GuppyConfigResource objStore = objectsStores[type];
    if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

    var transaction = _idb.transaction(objStore.name, 'readwrite');
    transaction.objectStore(objStore.name).put(object, id);

    return transaction.completed;
  }

  /**
   *
   */
  Future delete(String type, String id) {
    log.finest('_deleteFromDB $type / $id');

    GuppyConfigResource objStore = objectsStores[type];
    if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

    var transaction = _idb.transaction(objStore.name, 'readwrite');
    transaction.objectStore(objStore.name).delete(id);

    return transaction.completed;
  }

  /**
   *
   */
  Future _clearDB([String type]) {
    log.finest('_deleteFromDB $type');

    idb.Transaction transaction;
    // Clear database.
    if(type == null){
      objectsStores.forEach((k, GuppyConfigResource e){

        GuppyConfigResource objStore = e;
        if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

        transaction = _idb.transaction(objStore.name, 'readwrite');
        transaction.objectStore(objStore.name).clear();
      });
    } else {
      GuppyConfigResource objStore = objectsStores[type];
      if(objStore == null){log.severe('Guppy / IndexedDB / type non exist : $type');}

      transaction = _idb.transaction(objStore.name, 'readwrite');
      transaction.objectStore(objStore.name).clear();
    }

    return transaction.completed;
  }
}