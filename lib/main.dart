import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

void main()=>runApp(const OmApp());

class OmApp extends StatelessWidget{
  const OmApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'옴',
    theme:ThemeData(brightness:Brightness.dark,useMaterial3:true,
      scaffoldBackgroundColor:const Color(0xff0d1412),
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xffa7c4b5),brightness:Brightness.dark)),
    home:const HomePage());
}

class Program{
  final String name, subtitle;
  final IconData icon;
  const Program(this.name,this.subtitle,this.icon);
}
const programs=[
  Program('호흡 안정','호흡에 천천히 집중합니다',Icons.air),
  Program('마음 안정','복잡한 생각에서 잠시 벗어납니다',Icons.spa_outlined),
  Program('몸 이완','몸의 긴장을 하나씩 풀어갑니다',Icons.self_improvement),
  Program('수면 전','잠들기 전 조용히 가라앉습니다',Icons.nightlight_outlined),
];

class HomePage extends StatefulWidget{const HomePage({super.key});@override State<HomePage> createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{
  int minutes=10, completed=0, totalMinutes=0, selected=0;
  String lastSession='아직 완료한 명상이 없습니다.';
  List<String> history=[]; List<String> sessionJson=[]; bool resumable=false; int resumeRemaining=0; String resumeProgram='호흡 안정';
  @override void initState(){super.initState();
    WidgetsBinding.instance.addObserver(this);_load();}
  Future<void> _load()async{final p=await SharedPreferences.getInstance();setState((){completed=p.getInt('completed')??0;totalMinutes=p.getInt('totalMinutes')??0;
      lastSession=p.getString('lastSession')??'아직 완료한 명상이 없습니다.';
      history=p.getStringList('history')??[];
      sessionJson=p.getStringList('sessionJson')??[];
      resumable=p.getBool('sessionActive')??false;
      resumeRemaining=p.getInt('sessionRemaining')??0;
      resumeProgram=p.getString('sessionProgram')??'호흡 안정';
      if(resumeRemaining<=0) resumable=false;
    });}
  Future<void> _saveDone(int m)async{final p=await SharedPreferences.getInstance();completed++;totalMinutes+=m;await p.setInt('completed',completed);await p.setInt('totalMinutes',totalMinutes);
    final now=DateTime.now();
    lastSession='${now.month}월 ${now.day}일 · ${programs[selected].name} · $m분';
    await p.setString('lastSession',lastSession);
    history.insert(0,lastSession);
    if(history.length>100) history=history.take(100).toList();
    await p.setStringList('history',history);
    setState((){});}
  Future<void> _customTime()async{
    double v=10;
    final r=await showDialog<int>(context:context,builder:(c)=>AlertDialog(
      title:const Text('명상 시간 설정'),
      content:StatefulBuilder(builder:(c,setLocal)=>Column(mainAxisSize:MainAxisSize.min,children:[
        Text('${v.round()}분',style:const TextStyle(fontSize:32)),
        Slider(value:v,min:1,max:60,divisions:59,onChanged:(x)=>setLocal(()=>v=x))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('취소')),
        FilledButton(onPressed:()=>Navigator.pop(c,v.round()),child:const Text('확인'))]));
    if(r!=null)setState(()=>minutes=r);
  }
  Future<void> _saveStructuredSession(int m,int before,int after) async {
    final p=await SharedPreferences.getInstance();
    final now=DateTime.now();
    final rec='${now.toIso8601String()}|${programs[selected].name}|$m|$before|$after';
    sessionJson.insert(0,rec);
    if(sessionJson.length>100) sessionJson=sessionJson.take(100).toList();
    await p.setStringList('sessionJson',sessionJson);
  }
  Future<int?> _pickMood(String title) async {
    return showDialog<int>(context:context,builder:(c)=>AlertDialog(
      title:Text(title),
      content:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
        _mood(c,1,'긴장','😣'), _mood(c,2,'보통','😐'), _mood(c,3,'편안','😊')
      ]),
    ));
  }
  Widget _mood(BuildContext c,int v,String label,String emoji)=>InkWell(
    onTap:()=>Navigator.pop(c,v),
    borderRadius:BorderRadius.circular(16),
    child:Padding(padding:const EdgeInsets.all(10),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(emoji,style:const TextStyle(fontSize:34)),const SizedBox(height:6),Text(label)
    ])));
  @override Widget build(BuildContext context)=>Scaffold(
    body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,24,22,30),children:[
      const Center(child:Text('옴',style:TextStyle(fontSize:44,fontWeight:FontWeight.w200))),
      const SizedBox(height:4),const Center(child:Text('오늘도 잠시, 나에게 머무르세요.')),
      const SizedBox(height:28),
      ...List.generate(programs.length,(i)=>Card(
        child:ListTile(leading:Icon(programs[i].icon),title:Text(programs[i].name),
          subtitle:Text(programs[i].subtitle),trailing:selected==i?const Icon(Icons.check_circle):null,
          onTap:()=>setState(()=>selected=i)))),
      const SizedBox(height:22),
      if(resumable) Card(
        child:ListTile(
          leading:const Icon(Icons.restore),
          title:const Text('중단한 명상이 있습니다'),
          subtitle:Text('$resumeProgram · ${(resumeRemaining/60).ceil()}분 남음'),
          trailing:FilledButton(
            onPressed:()async{
              final prog=programs.firstWhere((x)=>x.name==resumeProgram,orElse:()=>programs[0]);
              final ok=await Navigator.push<bool>(context,MaterialPageRoute(
                builder:(_)=>MeditationPage(minutes:(resumeRemaining/60).ceil(),program:prog,initialSeconds:resumeRemaining)));
              if(ok==true) await _saveDone((resumeRemaining/60).ceil());
              final p=await SharedPreferences.getInstance();
              setState(()=>resumable=p.getBool('sessionActive')??false);
            },child:const Text('이어하기')),
        )),
      const SizedBox(height:22),
      const Text('시간',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final m in [3,5,10,20]) ChoiceChip(label:Text('$m분'),selected:minutes==m,onSelected:(_)=>setState(()=>minutes=m)),
        ActionChip(label:Text([3,5,10,20].contains(minutes)?'직접 설정':'$minutes분 ✓'),onPressed:_customTime)
      ]),
      const SizedBox(height:26),
      SizedBox(height:62,child:FilledButton(
        onPressed:()async{final before=await _pickMood('명상 전 지금의 상태는 어떤가요?');
          if(before==null)return;
          final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>MeditationPage(minutes:minutes,program:programs[selected])));
          if(ok==true){
            await _saveDone(minutes);
            if(context.mounted){
              final after=await _pickMood('명상 후 지금의 상태는 어떤가요?');
              if(after!=null && context.mounted){
                await _saveStructuredSession(minutes,before,after);
                await Navigator.push(context,MaterialPageRoute(builder:(_)=>ResultPage(
                  program:programs[selected].name,minutes:minutes,before:before,after:after)));
              }
            }
          }},
        child:Text('${programs[selected].name} · $minutes분 시작',style:const TextStyle(fontSize:19)))),
      const SizedBox(height:22),
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
        Column(children:[Text('$completed',style:const TextStyle(fontSize:26)),const Text('완료 횟수')]),
        Column(children:[Text('$totalMinutes',style:const TextStyle(fontSize:26)),const Text('누적 분')]),
      ]))),
      const SizedBox(height:10),
      Card(child:ListTile(leading:const Icon(Icons.history),title:const Text('최근 명상'),subtitle:Text(lastSession))),
      const SizedBox(height:10),
      OutlinedButton.icon(
        onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>HistoryPage(items:history,records:sessionJson))),
        icon:const Icon(Icons.list_alt),label:const Text('명상 기록 보기')), 
    ])));
}



class ResultPage extends StatelessWidget{
  final String program; final int minutes,before,after;
  const ResultPage({super.key,required this.program,required this.minutes,required this.before,required this.after});
  String mood(int x)=>x==1?'긴장됨':x==2?'보통':'편안함';
  @override Widget build(BuildContext context){
    final diff=after-before;
    final msg=diff>0?'명상 전보다 조금 더 편안해졌다고 기록되었습니다.'
      :diff==0?'명상 전후의 상태가 비슷하게 기록되었습니다.'
      :'오늘은 명상 후에도 긴장이 남아 있다고 기록되었습니다.';
    return Scaffold(appBar:AppBar(title:const Text('명상 완료')),body:Center(child:Padding(
      padding:const EdgeInsets.all(26),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        const Icon(Icons.spa_outlined,size:70),const SizedBox(height:22),
        const Text('오늘의 명상을 마쳤습니다',style:TextStyle(fontSize:25,fontWeight:FontWeight.w500)),
        const SizedBox(height:12),Text('$program · $minutes분'),
        const SizedBox(height:28),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('명상 전'),Text(mood(before))]),
          const Divider(),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('명상 후'),Text(mood(after))]),
        ]))),
        const SizedBox(height:16),Text(msg,textAlign:TextAlign.center),
        const SizedBox(height:30),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('완료'))
      ]))));
  }
}

class HistoryPage extends StatelessWidget{
  final List<String> items; final List<String> records;
  const HistoryPage({super.key,required this.items,required this.records});
  String _mood(int v)=>v==1?'긴장':v==2?'보통':'편안';
  String _detail(int i){
    if(i>=records.length)return '완료';
    final p=records[i].split('|');
    if(p.length<5)return '완료';
    return '${p[2]}분 · ${_mood(int.tryParse(p[3])??2)} → ${_mood(int.tryParse(p[4])??2)}';
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('명상 기록')),
    body:items.isEmpty
      ? const Center(child:Text('아직 완료한 명상이 없습니다.'))
      : ListView.separated(
          padding:const EdgeInsets.all(16),
          itemCount:items.length,
          separatorBuilder:(_,__)=>const Divider(height:1),
          itemBuilder:(_,i)=>ListTile(
            leading:CircleAvatar(child:Text('${items.length-i}')),
            title:Text(items[i]),
            subtitle:Text(_detail(i)),
          ),
        ),
  );
}

class MeditationPage extends StatefulWidget{
  final int minutes;final Program program; final int? initialSeconds;
  const MeditationPage({super.key,required this.minutes,required this.program,this.initialSeconds});
  @override State<MeditationPage> createState()=>_MeditationPageState();
}
class _MeditationPageState extends State<MeditationPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver{
  late int remaining; Timer? timer; bool running=true; late AnimationController breath;
  DateTime? endsAt;
  final FlutterTts tts=FlutterTts(); final AudioPlayer audio=AudioPlayer();
  int lastCue=-1;
  @override void initState(){super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    tts.setLanguage('ko-KR');
    // 자연스러운 여성 음성 품질 우선: 지나친 저속/피치 변형을 피한다.
    tts.setSpeechRate(0.48); tts.setVolume(0.86); tts.setPitch(1.0);
    _preferKoreanVoice();
    remaining=widget.initialSeconds ?? widget.minutes*60;
    endsAt=DateTime.now().add(Duration(seconds:remaining));
    _persistActive(true);
    breath=AnimationController(vsync:this,duration:const Duration(seconds:10),lowerBound:.70,upperBound:1)..repeat(reverse:true);
    timer=Timer.periodic(const Duration(seconds:1),(_) async {
      if(!running || endsAt==null)return;
      final left=endsAt!.difference(DateTime.now()).inSeconds;
      if(left<=0){
        timer?.cancel(); setState(()=>remaining=0); await _persistActive(false);
        await audio.play(AssetSource('audio/end.wav'));
        await Future.delayed(const Duration(milliseconds:800));
        await tts.speak('명상을 마칩니다. 천천히 눈을 떠보세요.');
      } else {
        setState(()=>remaining=left);
        if(remaining%10==0) await _persistActive(true);
        await _voiceCue();
      }
    });
    audio.play(AssetSource('audio/start.wav'));
    Future.delayed(const Duration(milliseconds:1200),()=>tts.speak('편안한 자세를 잡고, 천천히 호흡을 시작합니다.'));
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed && running && endsAt!=null){
      final left=endsAt!.difference(DateTime.now()).inSeconds;
      if(mounted)setState(()=>remaining=left<0?0:left);
    }
  }
  Future<void> _stopSession() async {
    final p=await SharedPreferences.getInstance();
    await p.setBool('sessionActive',false);
    await p.setInt('sessionRemaining',0);
  }
  Future<void> _persistActive(bool active) async {
    final p=await SharedPreferences.getInstance();
    await p.setBool('sessionActive',active);
    await p.setInt('sessionRemaining',remaining);
    await p.setString('sessionProgram',widget.program.name);
    await p.setString('sessionEndsAt',endsAt?.toIso8601String()??'');
  }
  Future<void> _preferKoreanVoice() async {
    try {
      final voices=await tts.getVoices;
      if(voices is List){
        final ko=voices.where((v)=>v is Map && (v['locale']?.toString().toLowerCase().startsWith('ko')??false)).toList();
        // 엔진이 제공하는 한국어 음성 중 하나를 사용. 성별 메타데이터가 없으면
        // 임의로 여성이라고 단정하지 않고 OS의 한국어 기본 음성을 사용한다.
        if(ko.isNotEmpty){
          final v=Map<String,dynamic>.from(ko.first as Map);
          if(v['name']!=null && v['locale']!=null) {
            await tts.setVoice({'name':v['name'].toString(),'locale':v['locale'].toString()});
          }
        }
      }
    } catch (_) {}
  }
  Future<void> _voiceCue() async {
    final elapsed=widget.minutes*60-remaining;
    final slot=elapsed~/120;
    if(slot==lastCue || elapsed<50)return;
    lastCue=slot;
    String cue='호흡을 바꾸려 하지 말고, 편안하게 바라보세요.';
    if(widget.program.name=='호흡 안정') cue='천천히 들이마시고, 더 길게 내쉬어 보세요.';
    if(widget.program.name=='마음 안정') cue='생각이 떠오르면 붙잡지 말고, 다시 호흡으로 돌아옵니다.';
    if(widget.program.name=='몸 이완') cue='어깨와 턱의 힘을 풀고, 몸이 가라앉는 느낌을 바라봅니다.';
    if(widget.program.name=='수면 전') cue='오늘 하루를 내려놓고, 몸의 무게를 편안히 맡겨보세요.';
    await tts.speak(cue);
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);timer?.cancel();tts.stop();audio.dispose();WakelockPlus.disable();breath.dispose();super.dispose();}
  String get clock=>'${(remaining~/60).toString().padLeft(2,'0')}:${(remaining%60).toString().padLeft(2,'0')}';
  String message(){
    if(remaining==0)return '수고하셨습니다';
    final elapsed=widget.minutes*60-remaining;
    if(elapsed<20)return '편안한 자세를 잡아보세요';
    if(widget.program.name=='몸 이완' && elapsed%90<25)return '어깨와 턱의 힘을 풀어주세요';
    if(widget.program.name=='마음 안정' && elapsed%90<25)return '떠오르는 생각을 그대로 흘려보내세요';
    if(widget.program.name=='수면 전' && elapsed%90<25)return '오늘 하루를 내려놓아도 괜찮습니다';
    return breath.status==AnimationStatus.reverse?'천천히 내쉬세요':'천천히 들이마셔요';
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.program.name)),
    body:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      AnimatedBuilder(animation:breath,builder:(_,__)=>Transform.scale(scale:breath.value,child:Container(
        width:210,height:210,decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0x339bb8a8)),
        alignment:Alignment.center,child:Text(message(),textAlign:TextAlign.center,style:const TextStyle(fontSize:21,height:1.45))))),
      const SizedBox(height:46),Text(clock,style:const TextStyle(fontSize:48,fontWeight:FontWeight.w200)),
      const SizedBox(height:30),
      if(remaining>0) FilledButton.tonal(onPressed:(){
        setState((){
          if(running){running=false;endsAt=null;}
          else{running=true;endsAt=DateTime.now().add(Duration(seconds:remaining));}
        });
        _persistActive(true);
      },child:Text(running?'일시정지':'계속하기'))
      else FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('명상 완료')),
      if(remaining>0) TextButton(onPressed:()async{
        final end=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
          title:const Text('명상을 종료할까요?'),
          content:const Text('종료하면 이번 명상은 완료 기록에 포함되지 않습니다.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('계속하기')),
            FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('종료'))]))??false;
        if(end){await _stopSession();if(context.mounted)Navigator.pop(context,false);}
      },child:const Text('종료'))
    ]))));
}
