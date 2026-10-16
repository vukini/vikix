'From Cuis7.7 [latest update: #7977] on 16 October 2026 at 12:00:00 pm'!
'Description Disposable Music interface comparison. The clock lives outside the image.'!
!provides: 'VikixMusic' 1 0!
!requires: 'Network-Kernel' 1 12 nil!
!requires: 'JSON' 1 0 nil!
SystemOrganization addCategory: #'VikixMusic'!

!classDefinition: #VikixMusic category: #'VikixMusic'!
Object subclass: #VikixMusic
 instanceVariableNames: 'socket buffer state problem queue worker closed port token'
 classVariableNames: ''
 poolDictionaries: ''
 category: 'VikixMusic'!
!classDefinition: 'VikixMusic class' category: #'VikixMusic'!
VikixMusic class instanceVariableNames: ''!

!classDefinition: #VikixMusicWindow category: #'VikixMusic'!
SystemWindow subclass: #VikixMusicWindow
 instanceVariableNames: 'lastState status grid paint page pattern'
 classVariableNames: ''
 poolDictionaries: ''
 category: 'VikixMusic'!
!classDefinition: 'VikixMusicWindow class' category: #'VikixMusic'!
VikixMusicWindow class instanceVariableNames: ''!

!VikixMusic class methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
openFrom: path
 | model window |
 model := self new.
 model connectFrom: path.
 window := VikixMusicWindow open: model label: 'Vikix Music - Cuis prototype'.
 window startStepping.
 ^ window! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
connectFrom: path
 | info |
 info := (FileEntry withAbsolutePathName: path) readStreamDo: [ :stream | Json readFrom: stream ].
 port := info at: 'port'. token := info at: 'token'.
 state := nil. problem := 'Connecting...'. closed := false.
 queue := SharedQueue new.
 worker := [
  [ self connect.
    self send: (Dictionary new at: 'token' put: token; yourself).
    state := self receive. problem := ''.
    [ closed ] whileFalse: [
      (Delay forMilliseconds: 500) wait.
      self send: (queue nextOrNil ifNil: [ Dictionary new at: 'op' put: 'state'; yourself ]).
      state := self receive ]
  ] on: Error do: [ :ex | problem := 'Disconnected: ', ex description ].
  socket ifNotNil: [ socket closeAndDestroy: 1 ]
 ] forkAt: Processor userBackgroundPriority! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
connect
 | request header |
 buffer := ByteArray new.
 socket := Socket newTCP.
 socket connectTo: #[127 0 0 1] port: port waitForConnectionFor: 3.
 request := 'GET /socket HTTP/1.1', String crlfString,
  'Host: 127.0.0.1:', port printString, String crlfString,
  'Upgrade: websocket', String crlfString, 'Connection: Upgrade', String crlfString,
  'Sec-WebSocket-Version: 13', String crlfString,
  'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==', String crlfString, String crlfString.
 socket sendData: request asUtf8Bytes.
 header := ''.
 [ header endsWith: String crlfString, String crlfString ] whileFalse: [
  header := header, (String fromUtf8Bytes: (self readBytes: 1)).
  header size > 4096 ifTrue: [ self error: 'oversized handshake' ] ].
 ((header beginsWith: 'HTTP/1.1 101') and: [ header includesSubString: 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=' ])
  ifFalse: [ self error: 'websocket handshake refused' ]! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
readBytes: count
 | deadline chunk got result |
 deadline := Time millisecondClockValue + 45000.
 [ buffer size < count ] whileTrue: [
  Time millisecondClockValue > deadline ifTrue: [ self error: 'music read timed out' ].
  socket waitForDataFor: 1 ifClosed: [ self error: 'music session closed' ] ifTimedOut: [].
  chunk := ByteArray new: 8192.
  got := socket receiveAvailableDataInto: chunk.
  got > 0 ifTrue: [ buffer := buffer, (chunk copyFrom: 1 to: got) ] ].
 result := buffer copyFrom: 1 to: count.
 buffer := buffer copyFrom: count + 1 to: buffer size.
 ^ result! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
send: object
 | bytes mask header |
 bytes := (Json render: object) asUtf8Bytes.
 bytes size > 4096 ifTrue: [ self error: 'music message too large' ].
 mask := ByteArray new: 4.
 1 to: 4 do: [ :i | mask at: i put: (256 atRandom) - 1 ].
 header := bytes size < 126
  ifTrue: [ ByteArray with: 129 with: (bytes size + 128) ]
  ifFalse: [ ByteArray with: 129 with: 254 with: (bytes size // 256) with: (bytes size \\ 256) ].
 1 to: bytes size do: [ :i | bytes at: i put: ((bytes at: i) bitXor: (mask at: ((i - 1) \\ 4) + 1)) ].
 socket sendData: header, mask, bytes! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
receive
 | header count |
 header := self readBytes: 2.
 (header first = 129 and: [ header second < 128 ]) ifFalse: [ self error: 'invalid music frame' ].
 count := header second.
 count = 127 ifTrue: [ self error: 'oversized music frame' ].
 count = 126 ifTrue: [ header := self readBytes: 2. count := header first * 256 + header second ].
 ^ Json readFrom: (String fromUtf8Bytes: (self readBytes: count)) readStream! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
state
 ^ state! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
problem
 ^ problem! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
sendCommand: command
 closed ifFalse: [ queue nextPut: command ]! !

!VikixMusic methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
close
 closed := true.
 worker ifNotNil: [ worker terminate. worker := nil ].
 socket ifNotNil: [ socket closeAndDestroy: 1. socket := nil ]! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
model
 ^ model! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
initialExtent
 ^ 820 @ 480! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
button: label do: block
 ^ PluggableButtonMorph model: block action: #value label: label! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
buildMorphicWindow
 | column controls |
 paint := 'a5'. page := 0. pattern := 1.
 column := LinearLayoutMorph newColumn.
 column gap: 12; padding: 16.
 controls := LinearLayoutMorph newRow.
 controls gap: 8.
 controls addMorph: (self button: 'Play' do: [ self play ]) proportionalWidth: 1;
  addMorph: (self button: 'Stop' do: [ self command: 'stop' ]) proportionalWidth: 1;
  addMorph: (self button: 'Tempo -' do: [ self tempo: -10 ]) proportionalWidth: 1;
  addMorph: (self button: 'Tempo +' do: [ self tempo: 10 ]) proportionalWidth: 1;
  addMorph: (self button: 'Gain -' do: [ self gain: -0.01 ]) proportionalWidth: 1;
  addMorph: (self button: 'Gain +' do: [ self gain: 0.01 ]) proportionalWidth: 1.
 status := LabelMorph contents: 'Connecting...'.
 grid := LinearLayoutMorph newColumn.
 grid gap: 8.
 column addMorph: (LabelMorph contents: 'VIKIX / MUSIC     Change a note. Hear it on the next bar.') fixedHeight: 30;
  addMorph: controls fixedHeight: 35;
  addMorph: status fixedHeight: 30;
  addMorph: grid proportionalHeight: 1;
  addMorph: (LabelMorph contents: 'Edits take a snapshot. Closing this view leaves the music running.') fixedHeight: 25.
 self layoutMorph addMorph: column proportionalWidth: 1.
 self startStepping! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
wantsSteps
 ^ true! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
statusText
 ^ status contents! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
stepTime
 ^ 300! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
step
 | value |
 value := model state.
 model problem isEmpty ifFalse: [ status contents: model problem. ^ self ].
 value ifNil: [ ^ self ].
 value = lastState ifTrue: [ ^ self ].
 lastState := value.
 self redraw! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
selected
 | patterns |
 patterns := lastState at: 'patterns'.
 pattern := pattern min: patterns size.
 ^ patterns at: pattern! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
redraw
 | row notes index cell transport |
 lastState ifNil: [ ^ self ].
 transport := (lastState at: 'playing') ifTrue: [ 'Playing ', (lastState at: 'pattern') ] ifFalse: [ 'Stopped' ].
 status contents: transport, '   ', (lastState at: 'tempo') printString, ' BPM   Gain ', (lastState at: 'gain') printString,
  '   ', (lastState at: 'error').
 grid removeAllMorphs.
 row := LinearLayoutMorph newRow. row gap: 8.
 row addMorph: (self button: ('Pattern: ', (self selected at: 'name')) do: [ self nextPattern ]) proportionalWidth: 1;
  addMorph: (self button: ('Paint: ', paint) do: [ self nextPaint ]) proportionalWidth: 1;
  addMorph: (self button: 'Previous steps' do: [ page := (page - 1) max: 0. self redraw ]) proportionalWidth: 1;
  addMorph: (self button: 'Next steps' do: [ page := (page + 1) min: ((self selected at: 'notes') size - 1 // 16). self redraw ]) proportionalWidth: 1.
 grid addMorph: row fixedHeight: 35.
 notes := self selected at: 'notes'.
 page := page min: (notes size - 1 // 16).
 1 to: 2 do: [ :r |
  row := LinearLayoutMorph newRow. row gap: 6.
  1 to: 8 do: [ :c |
   index := page * 16 + (r - 1 * 8) + c.
   index <= notes size ifTrue: [
    cell := self cell: index note: (notes at: index).
    row addMorph: cell proportionalWidth: 1 ] ].
  grid addMorph: row proportionalHeight: 1 ]! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
cell: index note: note
 ^ (self button: index printString, ': ', note do: [ self noteAt: index ])
  color: (note = '-' ifTrue: [ Color lightGray ] ifFalse: [ Color r: 0.65 g: 0.82 b: 0.75 ]); yourself! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
nextPattern
 pattern := pattern \\ (lastState at: 'patterns') size + 1.
 page := 0. self redraw! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
nextPaint
 | notes |
 notes := #('-' 'x' 'a5' 'b5' 'c6' 'd6' 'e6' 'f6' 'g6').
 paint := notes at: ((notes indexOf: paint) \\ notes size) + 1.
 self redraw! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
command: operation
 model sendCommand: (Dictionary new at: 'op' put: operation; yourself)! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
play
 lastState ifNil: [ ^ self ].
 model sendCommand: (Dictionary new at: 'op' put: 'play'; at: 'pattern' put: (self selected at: 'name'); yourself)! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
tempo: delta
 lastState ifNil: [ ^ self ].
 model sendCommand: (Dictionary new at: 'op' put: 'tempo'; at: 'revision' put: (lastState at: 'revision');
  at: 'value' put: ((((lastState at: 'tempo') + delta) max: 60) min: 200); yourself)! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
gain: delta
 lastState ifNil: [ ^ self ].
 model sendCommand: (Dictionary new at: 'op' put: 'gain';
  at: 'value' put: ((((lastState at: 'gain') + delta) max: 0) min: 0.1); yourself)! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
noteAt: index
 | note |
 lastState ifNil: [ ^ self ].
 note := ((self selected at: 'notes') at: index) = paint ifTrue: [ '-' ] ifFalse: [ paint ].
 model sendCommand: (Dictionary new at: 'op' put: 'note'; at: 'revision' put: (lastState at: 'revision');
  at: 'pattern' put: (self selected at: 'name'); at: 'step' put: index - 1; at: 'note' put: note; yourself)! !

!VikixMusicWindow methodsFor: 'music' stamp: 'vikix 10/16/2026 12:00'!
delete
 model close.
 super delete! !
