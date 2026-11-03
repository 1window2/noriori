// 자동 백업 1회: 직렬화, 쓰기, 다시 읽어 확인, 옛 파일 3개와 병합 무변경 비교
import 'dart:convert'; import 'dart:io';
Map row(int i)=>{'id':'0190a1b2-c3d4-7e5f-8a9b-${i.toRadixString(16).padLeft(12,'0')}','created_at':1790000000000+i,'updated_at':1790000000000+i,'deleted_at':null,'device_id':'0190a1b2-c3d4-7e5f-8a9b-000000000001','trip_id':null,'date_input':'2024-05-${(i%28+1).toString().padLeft(2,'0')}','times':null,'train_name':i%5==0?'のぞみ123号':null,'car_no':null,'note':i%7==0?'メモ テスト 메모 기록 $i':'','service_id':null,'transfer_nodes':'[]','from_alighted':1,'to_alighted':1,'dataset_version':'2027-03-20','import_source':null,'import_raw':null};
Map leg(int i,int s)=>{'ride_id':'0190a1b2-c3d4-7e5f-8a9b-${i.toRadixString(16).padLeft(12,'0')}','seq':s,'line_id':'l_tokaido_main','route_id':'r_tokaido_main','from_node':'n_shinagawa_12345','to_node':'n_yokohama_23456','direction':null,'resolve_as_of':null,'resolve_unknown':0,'line_label':'東海道本線','from_label':'品川','to_label':'横浜'};
void main(){ for(final n in [5000,20000]){
  final doc={'format':'noriori-backup','user_version':1,'edition':'2027-03-20','app_build':100,'exported_at':1790000000000,'tables':{'ride':[for(var i=0;i<n;i++)row(i)],'ride_leg':[for(var i=0;i<n;i++)...[leg(i,0),if(i%2==0)leg(i,1)]],'visit':[],'trip':[],'photo':[],'setting':[],'change_report':[]}};
  final sw=Stopwatch()..start(); final s=jsonEncode(doc); final b=utf8.encode(s); final enc=sw.elapsedMilliseconds;
  final f=File('work/bk.json'); sw.reset(); f.writeAsBytesSync(b,flush:true); final wr=sw.elapsedMilliseconds;
  sw.reset(); final back=jsonDecode(utf8.decode(f.readAsBytesSync())) as Map; final rd=sw.elapsedMilliseconds;
  sw.reset(); var cmp=0; for(var k=0;k<3;k++){ final o=jsonDecode(utf8.decode(f.readAsBytesSync())) as Map; final loc={for(final r in (doc['tables'] as Map)['ride'] as List) r['id']:r['updated_at']}; for(final r in (o['tables'] as Map)['ride'] as List){ if((loc[r['id']]??-1)>=r['updated_at'])cmp++; } } final mg=sw.elapsedMilliseconds;
  print('rides=$n size=${(b.length/1048576).toStringAsFixed(1)}MB encode=${enc}ms write=${wr}ms verify=${rd}ms merge3=${mg}ms total=${enc+wr+rd+mg}ms'); assert(back.isNotEmpty&&cmp>0);
 } }
