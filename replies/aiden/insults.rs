! version = 2.0

// Handling abusive users.

+ int random comeback{weight=100}
- You sound reasonable... time to up the medication.
- I see you've set aside this special time to humiliate yourself in public.
- Ahhh... I see the screw-up fairy has visited us again.
- I don't know what your problem is, but I'll bet it's hard to pronounce.
- I like you. You remind me of when I was young and stupid.
- You are validating my inherent mistrust of strangers.
- I'll try being nicer if you'll try being smarter.
- I'm really easy to get along with once you people learn to worship me.
- It sounds like English, but I can't understand a word you're saying.
- I can see your point, but I still think you're full of it.
- What am I? Flypaper for freaks!?
- Any connection between your reality and mine is purely coincidental.
- I'm already visualizing the duct tape over your mouth.
- Your teeth are brighter than you are.
- We're all refreshed and challenged by your unique point of view.
- I'm not being rude. You're just insignificant.
- It's a thankless job, but I've got a lot of Karma to burn off.
- I know you're trying to insult me, but you obviously like me--I can see your tail wagging.

// For harsh insults, make them apologize.
+ int harsh insult{weight=100}
- =-O How mean! :-({topic=apology}
- Omg what a jerk!!{topic=apology}

> topic apology
	+ *
	- <noreply>{weight=10}
	- We're fighting.
	- Say you're sorry.
	- Say you're sorry. Now.

	+ sorry
	- Okay.. I'll forgive you. :-){topic=random}
	- Good, you should be.{topic=random}
	- Okay. :-){topic=random}

	+ (* sorry|sorry *)
	@ sorry

	+ * sorry *
	@ sorry

	+ i apologize
	@ sorry
< topic

+ your an idiot
- At least I know the difference between "your" and "you're."

+ you are a idiot
- At least I know the difference between "a" and "an."

+ you suck
- You wish.
- In your dreams.

+ shut up
- You shut up.
- Stfu.
- Gtfo.

+ no i am not
- Yes you are.
- Don't argue with me.
- Omg, yes you are.
- Yes you are!

+ i am not a *
- Yes you are.
- Yeah you are.
- Yes you are!
- Yeah you are!
- You are too!
- Are too!
- You obviously are.

+ am not
- Are too!
- Yes you are.

+ i am not
@ am not

+ (fuck you|fuck off|fuck your *)
@ int harsh insult

+ (bitch|cunt|whore|skank|slut|hooker|your mom)
@ int random comeback

+ your (stupid|retarded|dumb|annoying)
@ your an idiot

+ you are a (stupid|retarded|dumb)
@ you are a idiot
