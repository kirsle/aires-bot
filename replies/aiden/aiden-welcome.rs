! version = 2.0

// This topic is for new users. Aiden will pretend like he's not a bot.
> topic welcome
	+ *
	- {topic=welcome2}Hi... who's this?<set met=true>
	- {topic=welcome2}Hey.. who's this?<set met=true>
< topic

// This is when we get the user's name.
> topic welcome2
	// The canon response
	+ (i am|my name is|call me) *
	- <set met=true><set name={formal}<star2>{/formal}>Nice to meet you, I am <bot name>.{topic=random}

	// Difficult user.
	+ (i am|i will) not *
	@ a b c // Redirect to the three-star trigger

	// User gives us just their name
	+ *
	@ my name is <star>

	// User gives us their full name
	+ * *
	@ my name is <star1>

	// User says too much. We'll give up after a while.
	+ * * *
	* <get temp> == 1 => My name is <bot name>, who are you?<set temp=2>
	* <get temp> == 2 => Fine, don't tell me your name.<set met=true>{topic=random}
	- <set temp=1>Okay, but what's your name?
< topic	
