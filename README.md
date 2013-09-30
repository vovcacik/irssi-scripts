Irssi scripts
=============

1. [translate.pl](#translatepl) - Translates incoming and outgoing messages on a per client basis.
2. [pastebin_inline.pl](#pastebin_inlinepl) - Pastes anything between start and end tag on pastebin.com - inline.
3. [context_aware_filter.pl](#context_aware_filterpl) - Filters status messages of those you did not talk to.
4. [blank_page.pl](#blank_pagepl) - Maintains blank page at the end of each scrollback.
5. [continuous_scrollback.pl](#continuous_scrollbackpl) - Switch to window with the highest activity level upon bottoming out scrollback.
6. [highlight_opening_message.pl](#highlight_opening_messagepl) - Highlights messages sent after period of silence on a per client basis.
7. [clear_screen_on_defocus.pl](#clear_screen_on_defocuspl) - Clears view upon switching to another window.
8. [fix_typo_for_real.pl](#fix_typo_for_realpl) - Applies vim-like substitution for real.

[translate.pl][]
----------------

### Syntax

```
/translate [list]
/translate [add] source [source_lang|* [target_lang]]
/translate remove source [source2...]
/translate save|reload|reset
```

### Description

Translates incoming and outgoing messages based on translation rules that allows
fine-grained control over what messages are translated to what languge.

A rule defines who is the `source` of messages to be translated and what foreign
language is the source using (`source_lang`). The source can be single client 
or a channel as a whole. The target language (`target_lang`) is what language
**you** are using.

This script is using Google Translate API which is not free and you will need
to obtain your own API key to use this script. However I have not been billed
by Google, there is apparently some unofficial free tier for this service.

### Examples

 - Translate everything the `troll_guy` says from Irish to English.
   - `/translate add troll_guy ga en`
 - You don't need to remember that `ga` is language code for Irish. You could
   use his TLD (see `/whois troll_guy`) or just the name of the language.
   - `/translate add troll_guy Irish en`
 - You also don't need to supply the English language code as long as you have
   `translate_default_target_lang` option set to your preferred language.
   - `/translate add troll_guy Irish`
 - If the `troll_guy` already said something (meaningful), you can let Google
   Translate API to detect language. And in none of the examples you were
   required to use the `add` keyword at all.
   - **`/translate troll_guy`**
 - Let's say you just joined `#trolls` channel and everyone there is speaking
   a language you just don't know. Also there is a guy `ubertroll` who is
   an exception, and you recognize he is speaking in German.
   - `/translate #trolls` and `/translate ubertroll`

With those commands issued everything you say in `#trolls` channel will be
translated to Irish (as Google Translate API detected on first command). However
if you will be talking directly to `ubertroll` (using the colon syntax) the
message will be translated to German (as the API detected on second command).
The same applies to incoming messages, with the exception `ubertroll` does not
have to address you. This means that more specific translation rules have
precedence over the others.

Note: the colon syntax is used to address particular client and is defined as:
`<client nickname>: <message>`

 - To list translation rules.
   - `/translate list` or the shortcut `/translate`
 - To save the rules in Irssi config.
   - `/translate save` and `/save`
 - You can reload the rules from config.
   - `/translate reload`
 - To remove a rule.
   - `/translate remove ubertroll`
 - To remove all rules.
   - `/translate reset`

### Settings

 - Saved rules in JSON: `/set translate_list {}`
 - Your preferred language (in valid language code): `/set translate_default_target_lang en`
 - Your own Google Translate API key: `/set translate_api_key YoUrOwNaPiKeY`
 - Number of lines to translate in scrollback upon adding a rule: `/set translate_scrollback_lines 3`



[pastebin_inline.pl][]
----------------------

### Syntax

`...message text...pastebin:<paste text>:pastebin...rest of the message.`

### Description

Uploads your pastes to Pastebin directly from Irssi. It works inline, which means
the pasted text is automatically replaced with the Pastebin link. What text is 
supposed to be pasted is determined by opening and closing tags. Anything between
those is sent to Pastebin and everything including the tags is replaced with URL.

All pastes are uploaded anonymously, unlisted and with expiration of 1 day by default.
If you got Pastebin account, you can associate the pastes with it by setting your
user API key - see the _Settings_ section and visit http://pastebin.com/api/api_user_key.html

Warning: once you type opening tag (`pastebin:` by default) you **have to** end
the gathering phase by closing tag (`:pastebin` by default). Everything in between
is just gathered to be uploaded to Pastebin, including commands like `/exit` etc.
Also the gathering can be started even inside commands, so something like this works:
`/me just uploaded pastebin:...multiline text...:pastebin Check it out!`

### Examples

 - What was typed:  
10:00 < you> Hi, what you guys think about pastebin:Lorem ipsum dolor sit amet, consectetur  
adipiscing elit. Morbi placerat velit  
metus, non accumsan nunc placerat et.:pastebin Let me know...  
10:00 < jim> That makes no sense dude.

 - What you and others see:  
10:00 < you> Hi, what you guys think about http://pastebin.com/KyVJGtHz Let me know...  
10:00 < jim> That makes no sense dude.

### Settings

 - API dev key (no need to change): `/set pastebin_inline_api_dev_key ba4e185a675b792c2288ba65cd84a96c`
 - Your private API user key (optional): `/set pastebin_inline_api_user_key yourAccountAccessToken`
 - Privacy settings (public = 0, unlisted = 1, private = 2): `/set pastebin_inline_api_paste_private 1`
 - Paste expiration (10M, 1H, 1D, 1W, 2W, 1M, N): `/set pastebin_inline_api_paste_expire_date 1D`
 - Start tag: `/set pastebin_inline_start_tag pastebin:`
 - End tag: `/set pastebin_inline_end_tag :pastebin`

It is strongly recommended to also disable `paste_join_multiline`. It is ON by
default and it tries to concatenate multiline text in one long line (paragraph).
It breaks any code pastes and does not work very well with normal text. You will
never miss it, I promise.
 - `/set paste_join_multiline OFF`



[context_aware_filter.pl][]
---------------------------

### Syntax

The colon syntax: `<nickname>: <message>`

### Description

This script filters out JOIN, PART, QUIT, NICK status messages except those that
are referring to someone you talked to recently.

To whitelist someone's status messages for next 15 minutes (the default value) you
have to use the colon syntax to address the message to him. During the period of time
you will see if he reconnects, quits or changes his nick.

### Settings

 - Forget you talked to them after this period of time: `/set context_aware_filter_forget_interval 900`



[blank_page.pl][]
-----------------

### Description

This script maintains blank page at the end of each scrollback (window). It is 
useful if you don't like to read text at the bottom edge of Irssi window or you
`/clear` your screen often. 



[continuous_scrollback.pl][]
----------------------------

### Description

This script will switch you to the next window with the highest activity level if
you double tap `Page Down` key (or whatever you got bound for scrolling) at the 
bottom of scrollback.

There are four activity levels: `highlight`, (public) `message`, `crap` (e.g. status 
messages), `none`. If there is more than one window of particular activity level, 
you will get switched in the first window in their _natural_ order. If there are
no windows with any activity, you will end up in `(status)` window.

Note: the scripts tries to prevent switching if you hold the page down key, but
if it does not do good job for you, tinker with the timings at line 42.



[highlight_opening_message.pl][]
--------------------------------

### Description

Highlights messages that opens a discussions or occur after period of inactivity
(5 minutes by default) on a per client basis.

### Examples

12:00 -!- _fan_ [example.com] has joined **#movies**  
12:00 < fan> **Hi, what was the best movie last year?**  
12:01 < fan> Anyone?  
12:01 < fan> Grrh :( lets ask Google.  
12:06 < fan> **Found it!**  
12:07 < fan> Bye.

### Settings

 - How long a client needs to be quiet to be highlighted: `/set highlight_opening_message_forget_interval 300`
 - How to [highlight][color formats] the message (bold by default): `/set highlight_opening_message_format %W`



[clear_screen_on_defocus.pl][]
------------------------------

### Description

When you switch to another window, issues `/clear` in the window you are leaving,
so when you switch back the new messages will be at the top edge of view (unless
you got autoscrolling enabled).



[fix_typo_for_real.pl][]
------------------------

### Syntax

`s/old text/new text/`

### Description

You know the guys that are using vim-like substitution syntax to correct their
typos in IRC? This script actually applies the substitution. However the 
substituted (new text) is highlighted with white background (by default) and the
substitution command is hidden from you.

### Examples

 - What they type:  
12:00 < a_guy> I just totally fayled there.  
12:01 < a_guy> s/fayled/failed/  
12:01 < troll> lol

 - and what you see:  
12:00 < a_guy> I just totally **failed** there.  
12:01 < troll> lol

### Settings

 - How to [highlight][color formats] the substituion (black text on white background by default): 
   `/set fix_typo_for_real_format %k%7`



[translate.pl]: translate.pl
[pastebin_inline.pl]: pastebin_inline.pl
[context_aware_filter.pl]: context_aware_filter.pl
[blank_page.pl]: blank_page.pl
[continuous_scrollback.pl]: continuous_scrollback.pl
[highlight_opening_message.pl]: highlight_opening_message.pl
[clear_screen_on_defocus.pl]: clear_screen_on_defocus.pl
[fix_typo_for_real.pl]: fix_typo_for_real.pl

[color formats]: http://www.irssi.org/documentation/formats
