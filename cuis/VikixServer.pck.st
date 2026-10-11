'From Cuis7.7 [latest update: #7977] on 9 October 2026 at 9:30:00 am'!
'Description The door into a running Cuis image, for vikix eval --cuis and the agents behind it.

VikixServer listens on 127.0.0.1 only (port 4005 unless the launcher says another). A client sends the password first, the first line of ~/.slime-secret, within five seconds, or is closed; the server goes on. Then a request is lines ending with a line of one dot (a line that starts with a dot had one added), evaluated in the UI process so the image stays safe, and the answer comes back the same way: a line saying ok or error, the value''s printString or the error, a dot. A request whose first line is door: WHO (an agent''s, as vikix eval --cuis sends it from under one) is walked by VikixWalker before it runs: every global it names and every message it sends must be on the walker''s lists, or the expression is held (the answer''s first line is held, then why) in VikixServer held for you to run (VikixServer runHeld: N) or drop. The door starts again when a saved image is opened, on the same port. Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixServer.pck.st in the Vikix checkout).'!
!provides: 'VikixServer' 1 0!
!requires: 'Network-Kernel' 1 12 nil!
SystemOrganization addCategory: #'VikixServer'!


!classDefinition: #VikixClient category: #'VikixServer'!
Object subclass: #VikixClient
	instanceVariableNames: 'socket buffer'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixServer'!
!classDefinition: 'VikixClient class' category: #'VikixServer'!
VikixClient class
	instanceVariableNames: ''!

!classDefinition: #VikixServer category: #'VikixServer'!
Object subclass: #VikixServer
	instanceVariableNames: 'port secretPath listener process'
	classVariableNames: 'Current Held HeldCount UserNamesPath'
	poolDictionaries: ''
	category: 'VikixServer'!
!classDefinition: 'VikixServer class' category: #'VikixServer'!
VikixServer class
	instanceVariableNames: ''!

!classDefinition: #VikixWalker category: #'VikixServer'!
Object subclass: #VikixWalker
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'VikixServer'!
!classDefinition: 'VikixWalker class' category: #'VikixServer'!
VikixWalker class
	instanceVariableNames: ''!


!VikixClient commentStamp: '<historical>' prior: 0!
One client of the door: its socket and the bytes read from it that no line has used yet. Lines come in and go out as UTF-8; a request or an answer is lines ending with a line of one dot.!

!VikixWalker commentStamp: '<historical>' prior: 0!
The door's check of an agent's expression, as door.lisp checks an agent's Lisp: the text is parsed, never run, and every node walked. A global it names must be on allowedGlobals (or in the user's file, VikixServer userNamesPath), a message it sends on allowedSelectors; what runs a program, touches a file, evaluates text of its own or reaches the system (Smalltalk, sockets, processes, quitting, thisContext) is refused; what defines or changes code, or waits holding the image, is held for the user; so is anything not on the lists. Assigning a global is held; a temporary is the expression's own. check: answers nil for an expression that may run, else {#refused or #held. why}, or {#error. why} for text that doesn't parse or names a variable nothing declares.!

!VikixServer commentStamp: '<historical>' prior: 0!
The door into this image: a TCP listener on 127.0.0.1 for vikix eval --cuis. One instance, Current, started by the launcher (VikixServer startOn: 4005 secret: '/home/me/.slime-secret') and again at each startup of a saved image. See the package description.!

!VikixClient methodsFor: 'reading' stamp: 'vikix 10/9/2026 09:30'!
readLineWithin: seconds
	"The next line, without its newline, as a ByteArray; nil when the client closed or seconds passed first."

	| deadline newline chunk count line |
	deadline := Time millisecondClockValue + (seconds * 1000).
	[ (newline := buffer indexOf: 10) = 0 ] whileTrue: [
		| left |
		left := deadline - Time millisecondClockValue.
		left <= 0 ifTrue: [ ^ nil ].
		socket waitForDataFor: left / 1000.0 ifClosed: [ ^ nil ] ifTimedOut: [ ^ nil ].
		chunk := ByteArray new: 4096.
		count := socket receiveAvailableDataInto: chunk.
		count = 0
			ifTrue: [ socket isConnected ifFalse: [ ^ nil ]]
			ifFalse: [ buffer := buffer, (chunk copyFrom: 1 to: count) ]].
	line := buffer copyFrom: 1 to: newline - 1.
	buffer := buffer copyFrom: newline + 1 to: buffer size.
	(line notEmpty and: [ line last = 13 ]) ifTrue: [ line := line allButLast ].
	^ line! !

!VikixClient methodsFor: 'reading' stamp: 'vikix 10/9/2026 09:30'!
readRequest
	"The lines up to one of a single dot, joined with newlines, as a String; a line that starts with a dot had one added. Nil when the client left."

	| bytes line |
	bytes := WriteStream on: (ByteArray new: 256).
	[
		line := self readLineWithin: 3600.
		line ifNil: [ ^ nil ].
		line = #[46] ] whileFalse: [
			bytes isEmpty ifFalse: [ bytes nextPut: 10 ].
			bytes nextPutAll: ((line notEmpty and: [ line first = 46 ]) ifTrue: [ line allButFirst ] ifFalse: [ line ]) ].
	^ String fromUtf8Bytes: bytes contents! !

!VikixClient methodsFor: 'reading' stamp: 'vikix 10/9/2026 09:30'!
readPasswordWithin: seconds
	"The first line, as a String; nil when it didn't come in time."

	^ (self readLineWithin: seconds) ifNotNil: [ :line | String fromUtf8Bytes: line ]! !

!VikixClient methodsFor: 'writing' stamp: 'vikix 10/9/2026 09:30'!
reply: status text: aString
	"STATUS (ok or error), the lines of aString each on its own (a dot added before one that starts with a dot), then a line of one dot."

	self sendLine: status.
	aString lines do: [ :each |
		(each notEmpty and: [ each first = $. ]) ifTrue: [ socket sendData: #[46] ].
		self sendLine: each ].
	self sendLine: '.'! !

!VikixClient methodsFor: 'writing' stamp: 'vikix 10/9/2026 09:30'!
sendLine: aString
	"As UTF-8: a String's own bytes are not."

	socket sendData: aString asUtf8Bytes.
	socket sendData: #[10]! !

!VikixClient methodsFor: 'initialization' stamp: 'vikix 10/9/2026 09:30'!
socket: aSocket

	socket := aSocket.
	buffer := ByteArray new! !

!VikixClient methodsFor: 'closing' stamp: 'vikix 10/9/2026 09:30'!
close

	socket ifNotNil: [ :s | s closeAndDestroy: 2 ].
	socket := nil! !

!VikixClient class methodsFor: 'instance creation' stamp: 'vikix 10/9/2026 09:30'!
on: aSocket

	^ self new socket: aSocket! !

!VikixServer methodsFor: 'accessing' stamp: 'vikix 10/9/2026 09:30'!
port

	^ port! !

!VikixServer methodsFor: 'accessing' stamp: 'vikix 10/9/2026 09:30'!
secretPath

	^ secretPath! !

!VikixServer methodsFor: 'accessing' stamp: 'vikix 10/9/2026 09:30'!
isRunning

	^ listener notNil and: [ listener isValid ]! !

!VikixServer methodsFor: 'initialization' stamp: 'vikix 10/9/2026 09:30'!
port: aPort secret: aPathName

	port := aPort.
	secretPath := aPathName! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
start
	"Listen on the loopback address alone. A port already taken leaves the door closed, with nothing else said: the launcher's doctor says so."

	self stop.
	listener := Socket newTCP.
	[ listener listenOn: port backlogSize: 4 interface: #[127 0 0 1] ]
		on: Error
		do: [ :ex | listener destroy. listener := nil. ^ self ].
	listener isValid ifFalse: [ listener := nil. ^ self ].
	process := [ self acceptLoop ] newProcess.
	process
		name: 'VikixServer ', port printString;
		priority: Processor userBackgroundPriority;
		resume! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
stop

	process ifNotNil: [ :p | p terminate ].
	process := nil.
	listener ifNotNil: [ :s | s destroy ].
	listener := nil! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
acceptLoop
	"Each client served in a process of its own, so a slow one keeps nobody out."

	[ listener notNil and: [ listener isValid ]] whileTrue: [
		(listener waitForAcceptFor: 10 ifTimedOut: [ nil ]) ifNotNil: [ :socket |
			[ self serve: (VikixClient on: socket) ] forkNamed: 'VikixServer client' ]]! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
serve: aClient
	"The password first, within five seconds, or the client is closed and nothing of it was run; then requests until the client goes."

	| secret |
	[
		secret := self secret.
		(secret notNil and: [ secret notEmpty and: [ (aClient readPasswordWithin: 5) = secret ]])
			ifFalse: [ ^ self ].
		[ aClient readRequest
			ifNil: [ ^ self ]
			ifNotNil: [ :text | | answer |
				"A fault in the door itself (the walker, the held list) is an error answer, never the end of the image: an error in a process of its own with no window would be."
				answer := [ self answer: text ] on: Error do: [ :ex | { 'error'. 'the door failed: ', ex description } ].
				"A client gone before its answer (its own deadline passed) is let go: a failed send in this process would end a headless image."
				[ aClient reply: answer first text: answer last ] on: Error do: [ :ex | ^ self ]]] repeat
	] ensure: [ aClient close ]! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
secret
	"The first line of the secret file; nil without the file, and then nobody comes in."

	| entry |
	secretPath ifNil: [ ^ nil ].
	entry := FileEntry withAbsolutePathName: secretPath.
	entry exists ifFalse: [ ^ nil ].
	^ [ entry readStreamDo: [ :stream | stream nextLine ]] on: Error do: [ :ex | nil ]! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
describe: anException
	"Its class, and what it says when it says something: ZeroDivide, or Error: not this way."

	| text |
	text := anException messageText.
	(text isNil or: [ text isEmpty or: [ text = anException class name ]])
		ifTrue: [ ^ anException class name ].
	^ anException class name, ': ', text! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/10/2026 18:00'!
answer: aString
	"A request answered: an agent's (first line door: WHO) walked first and held when it may not run; anyone else's evaluated as it is."

	| first expression from problem |
	(aString beginsWith: 'door: ') ifFalse: [ ^ self evaluate: aString ].
	first := aString lines first.
	from := first copyFrom: 7 to: first size.
	expression := aString copyFrom: (first size + 2 min: aString size + 1) to: aString size.
	problem := VikixWalker check: expression.
	problem ifNil: [ ^ self evaluate: expression ].
	problem first = #error ifTrue: [ ^ { 'error'. problem last } ].
	^ { 'held'. (self class hold: expression from: from why: problem last kind: problem first) }! !

!VikixServer methodsFor: 'running' stamp: 'vikix 10/9/2026 09:30'!
evaluate: aString
	"An Array: ok and the value's printString, or error and what went wrong. Run in the UI process, so Morphic is only ever touched from there; an image that doesn't get to it in 30 seconds (a dialog open) answers so."

	| answer done |
	done := Semaphore new.
	UISupervisor whenUIinSafeState: [
		answer := [ { 'ok'. (Compiler evaluate: aString) printString } ]
			on: Error, Warning
			do: [ :ex | { 'error'. self describe: ex } ].
		done signal ].
	(done waitTimeoutSeconds: 30) ifTrue: [ ^ { 'error'. 'the image is busy (a dialog open?)' } ].
	^ answer! !

!VikixServer class methodsFor: 'instance creation' stamp: 'vikix 10/9/2026 09:30'!
startOn: aPort secret: aPathName
	"The launcher's call: VikixServer startOn: 4005 secret: '/home/me/.slime-secret'"

	self stop.
	Current := self new port: aPort secret: aPathName.
	Current start.
	^ Current! !

!VikixServer class methodsFor: 'instance creation' stamp: 'vikix 10/9/2026 09:30'!
stop

	Current ifNotNil: [ :server | server stop ].
	Current := nil! !

!VikixServer class methodsFor: 'accessing' stamp: 'vikix 10/9/2026 09:30'!
current
	"The door, or nil"

	^ Current! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
hold: aString from: who why: why kind: kind
	"Keep an agent's expression for the user, ten at most (the same text again takes the old one's place), and answer the words for the agent: why, and what the user can do."

	| entry |
	Held ifNil: [ Held := OrderedCollection new ].
	Held removeAllSuchThat: [ :each | (each at: 4) = aString ].
	Held size >= 10 ifTrue: [ ^ why, '; the door holds ten expressions already, so this one was not kept' ].
	HeldCount := (HeldCount ifNil: [ 0 ]) + 1.
	entry := { HeldCount. who. self clock. aString. why. kind }.
	Held add: entry.
	^ why, '; held as ', HeldCount printString, ' for the user (VikixServer held; VikixServer runHeld: ', HeldCount printString, ', or dropHeld:)'! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
clock
	"The time of day as HH:MM."

	| now |
	now := Time now.
	^ (now hour printStringBase: 10 length: 2 padded: true), ':', (now minute printStringBase: 10 length: 2 padded: true)! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
held
	"The expressions the door holds, a few lines each: the number, who sent it, when, the text, and why; or nothing held."

	Held isEmptyOrNil ifTrue: [ ^ 'nothing held' ].
	^ String streamContents: [ :s |
		Held
			do: [ :each |
				s nextPutAll: (each at: 1) printString; nextPutAll: '  '; nextPutAll: (each at: 2); nextPutAll: '  '; nextPutAll: (each at: 3); newLine.
				(each at: 4) lines do: [ :line | s nextPutAll: '    '; nextPutAll: line; newLine ].
				s nextPutAll: '  '; nextPutAll: (each at: 5) ]
			separatedBy: [ s newLine ]]! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
heldAt: aNumber

	^ (Held ifNil: [ #() ]) detect: [ :each | (each at: 1) = aNumber ] ifNone: [ nil ]! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
heldCount

	^ Held ifNil: [ 0 ] ifNotNil: [ :h | h size ]! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
runHeld: aNumber
	"Run a held expression as yourself (from a Workspace, or vikix eval --cuis at your own terminal), and forget it: its value's printString, or the error. Evaluated here, in the caller's process: the door's own requests are already in the UI process."

	| entry |
	entry := self heldAt: aNumber.
	entry ifNil: [ ^ 'the door holds no expression ', aNumber printString ].
	Held remove: entry.
	^ [ (Compiler evaluate: (entry at: 4)) printString ] on: Error do: [ :ex | 'error: ', ex description ]! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
dropHeld: aNumber
	"Forget a held expression."

	| entry |
	entry := self heldAt: aNumber.
	entry ifNil: [ ^ 'the door holds no expression ', aNumber printString ].
	Held remove: entry.
	^ 'dropped ', aNumber printString! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
userNamesPath
	"The user's own names for the walker (~/.config/vikix/door, the Lisp door's file too), or nil."

	^ UserNamesPath! !

!VikixServer class methodsFor: 'the door' stamp: 'vikix 10/10/2026 18:00'!
userNamesPath: aPathName
	"The launcher's call: VikixServer userNamesPath: '/home/me/.config/vikix/door'"

	UserNamesPath := aPathName! !

!VikixServer class methodsFor: 'accessing' stamp: 'vikix 10/10/2026 12:00'!
state
	"What the image shows, a line a fact (key, a tab, value): the theme, the font, the packages, the door's port, how many expressions it holds, and a line a window (window, class, label). For vikix cuis status --json, and through it vikix mcp's cuis_state."

	^ String streamContents: [ :s |
		s nextPutAll: 'theme'; tab; nextPutAll: Theme current class name; newLine.
		s nextPutAll: 'font'; tab; nextPutAll: FontFamily defaultFamilyName, ' ', FontFamily defaultPointSize printString; newLine.
		s nextPutAll: 'packages'; tab.
		CodePackage installedPackages keys asSortedCollection
			do: [ :name | s nextPutAll: name ]
			separatedBy: [ s nextPutAll: ', ' ].
		s newLine.
		s nextPutAll: 'door'; tab; nextPutAll: (Current ifNil: [ 'closed' ] ifNotNil: [ :door | door isRunning ifTrue: [ door port printString ] ifFalse: [ 'closed' ]]); newLine.
		s nextPutAll: 'held'; tab; print: self heldCount; newLine.
		UISupervisor ui ifNotNil: [ :world |
			world submorphs do: [ :m |
				(m is: #SystemWindow) ifTrue: [
					s nextPutAll: 'window'; tab; nextPutAll: m class name; tab; nextPutAll: (m label ifNil: [ '' ]); newLine ]]]]! !

!VikixServer class methodsFor: 'system startup' stamp: 'vikix 10/9/2026 09:30'!
startUp: resuming
	"A saved image opened: its door opens again, on the same port."

	resuming ifTrue: [ Current ifNotNil: [ :server | server start ]]! !

!VikixServer class methodsFor: 'system startup' stamp: 'vikix 10/9/2026 09:30'!
shutDown: quitting
	"Before a save or a quit: the sockets go; the port and the path stay for the next start."

	Current ifNotNil: [ :server | server stop ]! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
check: aString
	"nil when the expression may run at the door; else {#refused or #held. why}, or {#error. why} for text that doesn't parse or names a variable nothing declares."

	| node problems |
	node := [[ Parser new parse: aString readStream class: UndefinedObject noPattern: true context: nil notifying: nil ifFail: [ nil ]]
		on: UndeclaredVariableWarning do: [ :warning | | name |
			name := warning instVarNamed: 'name'.
			"A name the image hasn't got (OSProcess) is refused all the same when it is one of the refused: the attempt is what counts."
			^ (self problemWithGlobal: name) ifNil: [ { #error. 'nothing declares ', name } ] ifNotNil: [ :problem |
				problem first = #refused ifTrue: [ problem ] ifFalse: [ { #error. 'nothing declares ', name } ]]]]
		on: Error do: [ :error | ^ { #error. error messageText ifNil: [ error description ] } ].
	node ifNil: [ ^ { #error. 'the text does not parse' } ].
	problems := OrderedCollection new.
	node nodesDo: [ :each | (self problemWith: each) ifNotNil: [ :problem | problems add: problem ]].
	problems isEmpty ifTrue: [ ^ nil ].
	"A refused one is what is said, before anything merely held; a refused name (Smalltalk) before a refused message (quit), since the name says more."
	^ problems
		detect: [ :problem | problem first = #refused and: [ (problem at: 2) beginsWith: 'it names' ]]
		ifNone: [ problems detect: [ :problem | problem first = #refused ] ifNone: [ problems first ]]! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
problemWith: aNode
	"nil, or the problem one node of the tree is."

	(aNode isKindOf: AssignmentNode) ifTrue: [
		(aNode variable isKindOf: LiteralVariableNode) ifTrue: [
			^ { #held. 'it sets ', aNode variable name, ', which is a global; a temporary of its own it may set' } ]].
	(aNode isKindOf: LiteralVariableNode) ifTrue: [ ^ self problemWithGlobal: aNode name ].
	(aNode isKindOf: VariableNode) ifTrue: [
		aNode name = 'thisContext' ifTrue: [ ^ { #refused. 'it names thisContext, which reaches the system' } ].
		^ nil ].
	(aNode isKindOf: MessageNode) ifTrue: [ ^ self problemWithSelector: aNode selectorSymbol ].
	^ nil! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
problemWithGlobal: aName

	^ self problemWith: aName how: 'names' allowed: self allowedGlobals! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
problemWithSelector: aSymbol

	| name |
	name := aSymbol asString.
	((name beginsWith: 'subclass:') or: [ name includesSubString: 'Subclass:instanceVariableNames:' ]) ifTrue: [
		^ { #held. 'it sends ', name, ', which defines or changes code' } ].
	^ self problemWith: name how: 'sends' allowed: self allowedSelectors! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
problemWith: aName how: how allowed: allowed
	"nil when a global or a selector may be named or sent, else the problem: refused by kind, held by kind, held for being on no list."

	(self kindOf: aName in: self refused) ifNotNil: [ :kind | ^ { #refused. 'it ', how, ' ', aName, ', which ', (kind at: 2) } ].
	(self kindOf: aName in: self asks) ifNotNil: [ :kind | ^ { #held. 'it ', how, ' ', aName, ', which ', (kind at: 2) } ].
	(allowed includes: aName) ifTrue: [ ^ nil ].
	(self userNames includes: aName) ifTrue: [ ^ nil ].
	^ { #held. 'it ', how, ' ', aName, ', which isn''t on the door''s list (VikixWalker allowedGlobals, allowedSelectors; your own go in ~/.config/vikix/door)' }! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
kindOf: aName in: kinds
	"The {kind. words. names} of kinds that has aName, or nil."

	^ kinds detect: [ :kind | (kind at: 3) includes: aName ] ifNone: [ nil ]! !

!VikixWalker class methodsFor: 'checking' stamp: 'vikix 10/10/2026 18:00'!
userNames
	"The names in the user's file, one a line, # starting a comment; read at each check, so a change needs no restart."

	| path entry |
	path := VikixServer userNamesPath.
	path ifNil: [ ^ #() ].
	entry := FileEntry withAbsolutePathName: path.
	entry exists ifFalse: [ ^ #() ].
	^ [ entry readStreamDo: [ :stream |
		(stream upToEnd lines collect: [ :line | (line copyUpTo: $#) withBlanksTrimmed ]) reject: [ :name | name isEmpty ]]]
		on: Error do: [ :ex | #() ]! !

!VikixWalker class methodsFor: 'the lists' stamp: 'vikix 10/10/2026 18:00'!
refused
	"What is refused outright, by kind: the kind, its words, then the globals and selectors. Globals that aren't in the image (OSProcess) are named all the same: a name is a name."

	^ {
		{ #shell. 'runs a program'. #('OSProcess' 'OSProcessAccessor' 'UnixProcess' 'PipeableOSProcess' 'ExternalCommand' 'ExternalFunction' 'ExternalLibrary' 'ExternalAddress' 'ExternalObjectTable' 'ExternalSemaphoreTable' 'ExternalStructure' 'FFI' 'Alien' 'command:' 'waitForCommand:' 'callFunction:' 'invokeWith:') }.
		{ #file. 'touches a file'. #('FileEntry' 'DirectoryEntry' 'FileSystemEntry' 'FileIOAccessor' 'UniFileStream' 'StdIOReadStream' 'StdIOWriteStream' 'CodeFile' 'CodePackageFile' 'FileList' 'FileListWindow' 'CuisSourceFileArray' 'IniFile' 'SourceFiles' 'ChangeSet' 'ChangeSorter' 'asFileEntry' 'asDirectoryEntry' 'fileIn' 'fileOut' 'fileOutOn:' 'fileContents' 'readStreamDo:' 'writeStreamDo:' 'appendStreamDo:' 'forceNewFile' 'fileNamed:' 'readAllTrueTypeFontsIn:' 'loadFrom:' 'loadFont:' 'saveToFile:' 'save') }.
		{ #eval. 'runs Smalltalk the door can''t see'. #('Compiler' 'Parser' 'Encoder' 'Decompiler' 'perform:' 'perform:with:' 'perform:with:with:' 'perform:with:with:with:' 'perform:with:with:with:with:' 'perform:withArguments:' 'perform:withArguments:inSuperclass:' 'perform:withPossiblyWrongSizedArguments:' 'evaluate:' 'evaluate:for:logged:' 'evaluate:for:notifying:logged:' 'evaluate:logged:' 'evaluate:notifying:logged:' 'instVarAt:put:' 'instVarNamed:put:' 'become:' 'becomeForward:' 'becomeForward:copyHash:' 'withArgs:executeMethod:' 'executeMethod:' 'eval:' 'act:' 'runHeld:' 'dropHeld:' 'answer:' 'hold:from:why:kind:') }.
		{ #system. 'reaches the system'. #('Smalltalk' 'SystemDictionary' 'Socket' 'SocketStream' 'SocketAddress' 'SocketAddressInformation' 'Process' 'Processor' 'ProcessorScheduler' 'Semaphore' 'Mutex' 'Undeclared' 'quit' 'quitPrimitive' 'quitPrimitive:' 'saveAndQuit' 'saveAndQuitAs:clearAllClassState:' 'saveAndStayAs:clearAllClassState:' 'saveAs' 'saveAs:' 'saveAs:clearAllClassState:' 'saveImage' 'snapshot:andQuit:embedded:clearAllClassState:' 'snapshotPrimitive' 'fork' 'forkAt:' 'forkNamed:' 'forkAt:named:' 'newProcess' 'newProcessWith:' 'terminate' 'suspend' 'resume' 'primitiveFailed' 'listenOn:' 'listenOn:backlogSize:interface:' 'connectTo:port:' 'connectTo:port:waitForConnectionFor:' 'sendData:' 'destroy' 'closeAndDestroy:' 'halt' 'halt:' 'startOn:secret:' 'stop' 'start' 'userNamesPath:' 'port:' 'addToStartUpList:' 'addToShutDownList:' 'removeFromStartUpList:' 'removeFromShutDownList:') } }! !

!VikixWalker class methodsFor: 'the lists' stamp: 'vikix 10/10/2026 18:00'!
asks
	"What is held for the user, by kind, without being refused: a change to the code the image runs, or a wait in its UI process."

	^ {
		{ #define. 'defines or changes code'. #('compile:' 'compile:classified:' 'compile:notifying:' 'compile:classified:notifying:' 'compileSilently:classified:' 'compile:classified:withStamp:notifying:' 'compile:classified:withStamp:libraryName:notifying:' 'compile:in:notifying:ifFail:' 'removeSelector:' 'basicRemoveSelector:' 'addInstVarName:' 'removeInstVarName:' 'addClassVarName:' 'removeClassVarName:' 'category:' 'comment:' 'removeFromSystem' 'removeFromSystem:' 'rename:' 'require:' 'install' 'methodsFor:' 'instanceVariableNames:' 'classVariableNames:' 'superclass:' 'addSelectorSilently:withMethod:' 'recompile:' 'recompileAll' 'installPackage' 'setDefaultFont:' 'useUniformColors' 'current:' 'beCurrent') }.
		{ #wait. 'waits, holding the image'. #('Delay' 'wait' 'wait:' 'waitTimeoutSeconds:' 'waitTimeoutMSecs:' 'request:' 'request:initialAnswer:' 'request:initialAnswer:verifying:' 'confirm:' 'confirm:orCancel:' 'inform:' 'chooseFrom:' 'chooseFrom:lines:title:' 'whenUIinSafeState:' 'runModal' 'forMilliseconds:' 'forSeconds:') } }! !

!VikixWalker class methodsFor: 'the lists' stamp: 'vikix 10/10/2026 18:00'!
allowedGlobals
	"The globals an agent's expression may name: the plain classes, the reads of the image, and Vikix's own (whose acts are the desktop's moves and switches, put back as easily as done)."

	^ #('Object' 'ProtoObject' 'Transcript' 'Theme' 'Color' 'Preferences' 'PreferenceSet' 'FontFamily' 'CodePackage' 'SystemOrganization' 'UISupervisor' 'SystemWindow' 'Morph' 'BrowserWindow' 'Browser'
		'String' 'Symbol' 'Text' 'Character' 'Array' 'OrderedCollection' 'Dictionary' 'IdentityDictionary' 'Set' 'IdentitySet' 'Bag' 'Interval' 'Association' 'Collection' 'SequenceableCollection' 'ByteArray'
		'Number' 'Integer' 'SmallInteger' 'Float' 'Fraction' 'Boolean' 'True' 'False' 'UndefinedObject' 'Point' 'Rectangle' 'Random'
		'Date' 'Time' 'DateAndTime' 'Duration' 'WriteStream' 'ReadStream' 'ReadWriteStream' 'Json' 'Behavior' 'Class' 'Metaclass'
		'VikixDesktop' 'VikixDesktopWindow' 'VikixWorkspaceMorph' 'VikixWindowMorph' 'VikixSwank' 'VikixServer' 'VikixTheme' 'VikixWalker')! !

!VikixWalker class methodsFor: 'the lists' stamp: 'vikix 10/10/2026 18:00'!
allowedSelectors
	"The messages an agent's expression may send: arithmetic, the collections, strings and streams, printing, what a class says of itself, the reads of Morphic and of Vikix's own objects, and VikixDesktop's acts."

	^ #('+' '-' '*' '/' '//' '\\' '<' '>' '<=' '>=' '=' '~=' '==' '~~' 'max:' 'min:' 'abs' 'negated' 'sqrt' 'squared' 'raisedTo:' 'ln' 'log:' 'floor' 'ceiling' 'rounded' 'truncated' 'roundTo:' 'isZero' 'sign' 'between:and:' 'even' 'odd' 'isInteger' 'isNumber' 'isString' 'isSymbol' 'isNil' 'notNil' 'isEmptyOrNil' 'gcd:' 'lcm:' 'printString:' 'printStringBase:' 'asCharacter' 'asInteger' 'asFloat' 'asNumber' 'atRandom'
		'&' '|' 'and:' 'or:' 'not' 'xor:' 'ifTrue:' 'ifFalse:' 'ifTrue:ifFalse:' 'ifFalse:ifTrue:' 'ifNil:' 'ifNotNil:' 'ifNil:ifNotNil:' 'ifNotNil:ifNil:'
		'value' 'value:' 'value:value:' 'value:value:value:' 'value:value:value:value:' 'valueWithArguments:' 'whileTrue:' 'whileFalse:' 'whileTrue' 'whileFalse' 'to:do:' 'to:by:do:' 'timesRepeat:' 'ensure:' 'ifCurtailed:' 'on:do:' 'yourself' 'numArgs'
		'class' 'name' 'printString' 'displayString' 'printOn:' 'displayStringOn:' 'storeString' 'asString' 'asSymbol' 'hash' 'copy' 'deepCopy' 'shallowCopy' 'isKindOf:' 'isMemberOf:' 'respondsTo:' 'is:' '->' 'key' 'value' 'species' 'superclass' 'subclasses' 'allSubclasses' 'allSuperclasses' 'withAllSuperclasses' 'withAllSubclasses' 'selectors' 'allSelectors' 'instVarNames' 'allInstVarNames' 'classVarNames' 'category' 'comment' 'organization' 'categories' 'listAtCategoryNamed:' 'includesSelector:' 'canUnderstand:' 'compiledMethodAt:' 'compiledMethodAt:ifAbsent:' 'sourceCode' 'sourceCodeAt:' 'isMeta' 'theNonMetaClass' 'classNames' 'whichClassIncludesSelector:' 'instanceCount' 'allInstances' 'classesDo:' 'classes' 'packageName' 'methodCount'
		'size' 'isEmpty' 'notEmpty' 'ifEmpty:' 'ifNotEmpty:' 'ifEmpty:ifNotEmpty:' 'do:' 'collect:' 'select:' 'reject:' 'detect:' 'detect:ifNone:' 'inject:into:' 'do:separatedBy:' 'doWithIndex:' 'withIndexDo:' 'keysAndValuesDo:' 'keysDo:' 'valuesDo:' 'reverseDo:' 'allSatisfy:' 'anySatisfy:' 'includes:' 'includesKey:' 'indexOf:' 'at:' 'at:ifAbsent:' 'at:ifAbsentPut:' 'at:put:' 'add:' 'addAll:' 'addFirst:' 'addLast:' 'remove:' 'remove:ifAbsent:' 'removeKey:' 'removeKey:ifAbsent:' 'removeAll:' 'removeFirst' 'removeLast' 'first' 'last' 'first:' 'last:' 'allButFirst' 'allButLast' 'allButFirst:' 'allButLast:' 'copyFrom:to:' 'copyWith:' 'copyWithout:' 'copyReplaceAll:with:' 'copyReplacing:with:' ',' 'reversed' 'reverse' 'asArray' 'asOrderedCollection' 'asSortedCollection' 'asSortedCollection:' 'asSet' 'asBag' 'asDictionary' 'sort' 'sort:' 'sorted' 'sorted:' 'keys' 'values' 'associations' 'associationsDo:' 'count:' 'max' 'min' 'sum' 'detectMax:' 'detectMin:' 'anyOne' 'with:collect:' 'with:do:' 'readStream' 'writeStream' 'contents' 'streamContents:' 'new' 'new:' 'with:' 'with:with:' 'with:with:with:' 'with:with:with:with:' 'withAll:' 'new:withAll:' 'newFrom:' 'isCollection' 'isArray' 'asByteArray'
		'asUppercase' 'asLowercase' 'capitalized' 'withBlanksTrimmed' 'lines' 'substrings' 'substrings:' 'subStrings:' 'beginsWith:' 'endsWith:' 'includesSubString:' 'asText' 'asUtf8Bytes' 'fromUtf8Bytes:' 'format:' 'join:' 'replaceAll:with:' 'padded:to:' 'printPaddedWith:to:' 'asPlainString' 'copyUpTo:' 'copyAfter:' 'indexOf:ifAbsent:' 'occurrencesOf:' 'isLetter' 'isDigit' 'isUppercase' 'isLowercase' 'asciiValue' 'value:'
		'nextPutAll:' 'nextPut:' 'next' 'next:' 'peek' 'atEnd' 'upToEnd' 'upTo:' 'skip:' 'nextLine' 'print:' 'tab' 'space' 'newLine' 'cr' 'tab:' 'space:' 'show:' 'nl' 'newLineString'
		'today' 'now' 'year' 'month' 'day' 'dayOfWeek' 'hour' 'minute' 'second' 'asSeconds' 'millisecondClockValue' 'totalSeconds' 'asDate' 'asTime' 'monthName' 'dayOfMonth' 'daysInMonth' 'addDays:' 'subtractDays:' 'daysFrom:'
		'@' 'x' 'y' 'extent' 'corner' 'origin' 'width' 'height' 'topLeft' 'bottomRight' 'center'
		'current' 'background' 'text' 'textHighlight' 'textPane' 'paneBackgroundFrom:' 'defaultWindowColor' 'focusIndicator' 'red' 'green' 'blue' 'black' 'white' 'gray' 'r:g:b:' 'fromHexString:' 'printHexString' 'alpha' 'lighter' 'darker' 'defaultFamilyName' 'defaultPointSize' 'installedPackages' 'ui' 'submorphs' 'allMorphsDo:' 'label' 'owner' 'color' 'morphExtent' 'morphPosition' 'morphBounds' 'displayBounds' 'isWindow'
		'open' 'window' 'model' 'summary' 'summaryOn:' 'windowMorphs' 'windowNumbered:' 'windowNumbered:on:' 'workspaceNumbered:' 'number' 'title' 'windowClass' 'hasFocus' 'line' 'kind' 'isCurrent' 'latest' 'error' 'said' 'desktop' 'port' 'secretPath' 'isRunning' 'state' 'held' 'heldCount' 'heldAt:' 'userNamesPath' 'check:' 'allowedGlobals' 'allowedSelectors' 'refused' 'asks' 'userNames' 'moveWindow:from:to:' 'focusWindow:on:' 'switchTo:' 'fullOnClass:selector:' 'fontFamilyName')! !

!VikixServer class methodsFor: 'class initialization' stamp: 'vikix 10/9/2026 09:30'!
initialize
	"VikixServer initialize"

	Smalltalk addToStartUpList: self.
	Smalltalk addToShutDownList: self! !
VikixServer initialize!
