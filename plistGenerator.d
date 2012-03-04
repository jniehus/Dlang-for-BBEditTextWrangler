#!/usr/local/bin/rdmd	

module plistGenerator;

import std.stdio, std.conv, std.string, std.regex;
import std.file, std.xml, std.stream, std.algorithm;

private string[] keywords;
private string[] specialTokens;
private string[] phobosModules;

private string plistHeader = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>BBEditDocumentType</key>
  <string>CodelessLanguageModule</string>
  <key>BBLMColorsSyntax</key>
  <true/>
  <key>BBLMIsCaseSensitive</key>
  <true/>
  <key>BBLMKeywordList</key>
  <array>
";
   

// closes off the header's <array>
private string plistBlocks = "    </array>
	  <key>BBLMSuffixMap</key>
	  <array>
		  <dict>
			  <key>BBLMLanguageSuffix</key>
			  <string>d</string>
		  </dict>
	  </array>        
    <key>BBLMLanguageCode</key>
    <string>CDpl</string>
    <key>BBLMLanguageDisplayName</key>
    <string>D Programming Language</string>
    <key>BBLMScansFunctions</key>
    <true/>
    <key>Language Features</key>
    <dict>
        <key>Comment Pattern</key>
        <string>(?x:
            (?&gt;	//	.*			  $			  ) |
            (?&gt;	\\#!	.*			  $				) |            
            (?&gt;	/\\*		(?s:.*?)	(?: \\*/ | \\z )	) |
            (?&gt;	/\\+		(?s:.*?)	(?: \\+/ | \\z )	)
        )</string>
        <key>Function Pattern</key>
        <string>(?x:
            (?P&lt;function&gt;
            
                (?P&lt;function_name&gt;
                    (?&gt; _* [A-Za-z] [A-Za-z0-9_]* )
                    (?:
                        (?:
                            (?&gt;
                                (?&gt; \\s+ ) | (?P&gt;comment) | (?P&gt;string)
                            )
                        )*
                        ::
                        (?:
                            (?&gt;
                                (?&gt; \\s+ ) | (?P&gt;comment) | (?P&gt;string)
                            )
                        )*
                        ~?	_* [A-Za-z] [A-Za-z0-9_]*
                    )?
                )
                
                (?:
                    (?&gt;
                        (?&gt; \\s+ ) | (?P&gt;comment) | (?P&gt;string)
                    )
                )*
                
                (?P&lt;parens&gt;
                    \\(
                        (?:
                            (?&gt;
                                (?&gt; [^'\"()]+ ) | (?: / (?![/*]) ) | (?P&gt;comment) | (?P&gt;string) | (?P&gt;parens)
                            )
                        )*
                    \\)
                )
                
                (?:
                    (?&gt;
                        (?&gt; \\s+ ) | (?P&gt;comment) | (?P&gt;string)
                    )
                )*
                
                (?:
                    :
                    (?:
                        (?&gt;
                            (?&gt; [^'\"{]+ ) | (?: / (?![/*]) ) | (?P&gt;comment) | (?P&gt;string)
                        )
                    )*
                )?
                
                (?P&lt;braces&gt;
                    {
                        (?:
                            (?&gt;
                                (?&gt; [^'\"{}]+ ) | (?: / (?![/*]) ) | (?P&gt;comment) | (?P&gt;string) | (?P&gt;braces)
                            )
                        )*
                    }
                )
            )
        )</string>
        <key>Identifier and Keyword Character Class</key>
        <string>0-9A-Z_a-z</string>
        <key>Skip Pattern</key>
        <string>(?x:
            (?&gt;
                (?P&gt;comment) | (?P&gt;string)
            )
        )</string>
        <key>String Pattern</key>
        <string>(?x:
            (?&gt;	 \"	(?s: \\\\. | [^\"] )*?		(?: \" | \\z)	)	|
            (?&gt;	r\"	(?s: \\\\. | [^\"] )*?		(?: \" | \\z)	) |
            (?&gt;   '  (?s: \\\\. | [^']  )*?    (?: '  | \\z) ) |
            (?&gt;	q\"	(?s: \\\\. | [^\"] )*?		(?: \" | \\z)	) |
            (?&gt;  q{ .* }(?!})  )
        )</string>
    </dict>
</dict>
</plist>";

// closes <array> from blocks and headers <dict><plist>
private string plistFooter = "</array>
<key>wordCharacters</key>
<string>_</string>
</dict>
</plist>";

string plistWrap(string key) {
    return "      <string>" ~ key ~ "</string>\n";  
}

void main()
{
    string[] deprecatedModules = ["std.cpuid", "std.ctype", "std.date", "std.gregorian", "std.regexp"];
    string dlangOrgStd = "/Users/joshuaniehus/GIT/d-programming-language.org/std.ddoc";
    string dlangOrgLex = "/Users/joshuaniehus/GIT/d-programming-language.org/lex.dd";
    auto ddStdDoc = std.stdio.File(dlangOrgStd, "r");
    auto ddLexDoc = std.stdio.File(dlangOrgLex, "r");
    
    foreach(string line; lines(ddStdDoc)) {
        auto m = match(line, regex(r"(>[a-z]{1,99}\.[a-z0-9]{1,99}</a>\))|(>[a-z]{1,99}\.[a-z0-9]{1,99}\.[a-z0-9]{1,99}</a>\))"));
        if (m) {
            string phobosModule = m.hit()[1 .. $-5]; // shave off the > and the </a>)
            if (find(deprecatedModules, phobosModule) == []) {
                phobosModules ~= phobosModule;
            }
        }
    }
    
    foreach(string line; lines(ddLexDoc)) {
        auto k = match(line, regex(r"\$\(B\s+([a-z]{2,99}|[a-z]{2,99}_[a-z]{1,99}|__[A-Za-z]{1,99})\)"));
        auto t = match(line, regex(r"CODE\s+__[A-Z]{1,99}__\)"));
        if (k) {
            string[] splitKeyword = std.array.split(k.hit());
            keywords ~= splitKeyword[1][0 .. $-1];
        }
        
        if (t) {
            string[] splitToken = std.array.split(t.hit());
            specialTokens ~= splitToken[1][0 .. $-1];
        }         
    }
    
    // more special case keywords
    keywords ~= "string"; 
    keywords ~= "wstring"; 
    keywords ~= "dstring";     
    keywords ~= "size_t";
    keywords ~= "ptrdiff_t";
    keywords ~= "sizediff_t";
    keywords ~= "hash_t";
    keywords ~= "equals_t";    
        
    string plist = "";
    plist ~= plistHeader;
    foreach(string keyword; keywords) {
        plist ~= plistWrap(keyword);
    }
    foreach(string token; specialTokens) {
        plist ~= plistWrap(token);
    }
    foreach(string phobosModule; phobosModules) {
        plist ~= plistWrap(phobosModule);
    }            
    plist ~= plistBlocks;    
    
    std.xml.check(plist);    
    std.stream.File f = new std.stream.File();
    string bbeditLoc = "DCodelessLanguageModule.plist";
    f.create(bbeditLoc);
    f.writeString(plist);
    writeln(plist);
    
    writeln(keywords.length + specialTokens.length + phobosModules.length);    
}