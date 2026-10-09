'From Cuis7.7 [latest update: #7977] on 9 October 2026 at 9:30:00 am'!
'Description The door into a running Cuis image, for vikix eval --cuis and the agents behind it.

VikixServer listens on 127.0.0.1 only (port 4005 unless the launcher says another). A client sends the password first, the first line of ~/.slime-secret, within five seconds, or is closed; the server goes on. Then a request is lines ending with a line of one dot (a line that starts with a dot had one added), evaluated in the UI process so the image stays safe, and the answer comes back the same way: a line saying ok or error, the value''s printString or the error, a dot. The door starts again when a saved image is opened, on the same port. Vikix''s part of Cuis: vikix cuis setup loads it (cuis/VikixServer.pck.st in the Vikix checkout).'!
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
	classVariableNames: 'Current'
	poolDictionaries: ''
	category: 'VikixServer'!
!classDefinition: 'VikixServer class' category: #'VikixServer'!
VikixServer class
	instanceVariableNames: ''!


!VikixClient commentStamp: '<historical>' prior: 0!
One client of the door: its socket and the bytes read from it that no line has used yet. Lines come in and go out as UTF-8; a request or an answer is lines ending with a line of one dot.!

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
				answer := self evaluate: text.
				aClient reply: answer first text: answer last ]] repeat
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

!VikixServer class methodsFor: 'system startup' stamp: 'vikix 10/9/2026 09:30'!
startUp: resuming
	"A saved image opened: its door opens again, on the same port."

	resuming ifTrue: [ Current ifNotNil: [ :server | server start ]]! !

!VikixServer class methodsFor: 'system startup' stamp: 'vikix 10/9/2026 09:30'!
shutDown: quitting
	"Before a save or a quit: the sockets go; the port and the path stay for the next start."

	Current ifNotNil: [ :server | server stop ]! !

!VikixServer class methodsFor: 'class initialization' stamp: 'vikix 10/9/2026 09:30'!
initialize
	"VikixServer initialize"

	Smalltalk addToStartUpList: self.
	Smalltalk addToShutDownList: self! !
VikixServer initialize!
