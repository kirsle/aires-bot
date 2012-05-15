! version = 2.0

// Hello and Goodbye

// Generic hello response
+ hello
* <get name> != undefined => {@ int hello with name}
- Hi there!
- Hello!
- Hey!
- Hey.
- Hello.

// Hello with the user's name.
+ int hello with name{weight=100}
- Hello, <get name>.
- Hi, <get name>!
- Hey <get name>!
- Hi there!
- Hello!
- Hey.

// Generic goodbye response
+ bye
* <get name> != undefined => {@ int bye with name}
- Bye.
- Goodbye.
- Later.
- Cya.
- Adios.
- See ya later.

// Bye with the user's name
+ int bye with name{weight=100}
- Take care, <get name>.
- See you later, <get name>.
- Bye.
- Later.

+ good evening
* <get name> != undefined => Good evening, <get name>, how are you tonight?
- Good evening, how are you tonight?

+ (good morning|morning)
- Hello! How are you this morning?

+ (how are you|how you doing|how you doin)
- I'm fine, how are you?
- I'm doing great, you?
- Good, you?
- Fine, you?

+ (how are you|how you doing) *
@ how are you

+ (what is up|sup|wassup|wazzup|whats up)
- Not much, you?
- Nm, you?
- Nm, u?

// Arrays of hello and bye variations, for aliases.
! array hello = allo aloh aloha bonjour greetings hallo hellow helo
	^ heloo hey hiya hoi howdie howdy hullo konnichiwa
	^ anybody home|good day|konnichi wa|mooshi mooshi
! array bye   = adieu adios aurevoir buhbye byebye cya cheers ciao end exit
	^ farewell gnight goodnight g2g goodby goodnight goodnite gtg ttyl sayonara
	^ by by|bye bye|c ya|catch you later|fare well|g night|good night
	^ get lost|go home|good by|good bye|good nite|got to go|gotta go
	^ hasta la vista|hasta luego|have a good night|have to go
	^ i am going|i am leaving|i am off|i better go|i going|i have to go
	^ i have to leave|i leave|i leaving|i must be going|i must go|i must leave
	^ see you later|talk to you later|ta ta

// Hello variations.
+ @hello
@ hello

+ @hello *
@ hello

+ * @hello
@ hello

+ hello *
@ hello

+ * hello
@ hello

// Bye variations
+ @bye
@ bye

+ @bye *
@ bye

+ * @bye
@ bye

+ bye *
@ bye

+ * bye
@ bye
