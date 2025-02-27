/* Copyright (C) 2014 InfiniDB, Inc.
   Copyright (C) 2016 MariaDB Corporation

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; version 2 of
   the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA. */

/* $Id: dml.l 8707 2012-07-13 19:08:12Z rdempsey $ */
%{
#include <iostream>
#include <vector>
#include <stdio.h>
#include <cstring>
#include "dmlparser.h"

#undef DECIMAL
#undef DELETE
#undef IN
#include "dml-gram.h"

/* These don't seem to be covered by the prefix option of flex 2.5.4
 * Bison 2.0 puts extern dml_yylval in dml-gram.h. */

/*#define yylval dml_yylval
#define yyerror dml_yyerror*/
using namespace dmlpackage;

void dmlerror(yyscan_t yyscanner, char const *s);

namespace dmlpackage {
int lineno = 1;


static char* scanner_copy (char *str, yyscan_t yyscanner);


/* macro to save the text and return a token */
#define TOK(name) { dmlget_lval(yyscanner)->strval = scanner_copy(dmlget_text(yyscanner), yyscanner); return name; }
}

%}

%option reentrant
%option bison-bridge
%option noyywrap
%option nounput
%x inquote
%x endquote

quote '

%%

ALL		TOK(ALL)
AND		TOK(AND)
AVG		TOK(AMMSC)
MIN		TOK(AMMSC)
MAX		TOK(AMMSC)
SUM		TOK(AMMSC)
COUNT	        TOK(AMMSC)
ANY		TOK(ANY)
AS		TOK(AS)
ASC		TOK(ASC)
AUTHORIZATION	TOK(AUTHORIZATION)
BETWEEN		TOK(BETWEEN)
BY	       	TOK(BY)
CHAR(ACTER)?    TOK(CHARACTER)
CHECK		TOK(CHECK)
CLOSE		TOK(CLOSE)
COMMIT		TOK(COMMIT)
CONTINUE	TOK(CONTINUE)
CREATE		TOK(CREATE)
CURRENT		TOK(CURRENT)
CURSOR		TOK(CURSOR)
DECIMAL		TOK(IDB_DECIMAL)
DECLARE		TOK(DECLARE)
DEFAULT		TOK(DEFAULT)
DELETE		TOK(DELETE)
DESC		TOK(DESC)
DISTINCT	TOK(ALL)
DOUBLE		TOK(IDB_DOUBLE)
ESCAPE		TOK(ESCAPE)
EXISTS		TOK(EXISTS)
FETCH		TOK(FETCH)
FLOAT		TOK(IDB_FLOAT)
FOR	        TOK(FOR)
FOREIGN		TOK(FOREIGN)
FOUND		TOK(FOUND)
FROM		TOK(FROM)
GO[ \t]*TO	TOK(GOTO)
GRANT		TOK(GRANT)
GROUP		TOK(IDB_GROUP)
HAVING		TOK(HAVING)
IN	      	TOK(IN)
INDICATOR	TOK(INDICATOR)
INSERT		TOK(INSERT)
INT(EGER)?	TOK(INTEGER)
INTO		TOK(INTO)
IS	       	TOK(IS)
KEY	        TOK(KEY)
LANGUAGE	TOK(LANGUAGE)
LIKE		TOK(LIKE)
NOT	        TOK(NOT)
NULL		TOK(NULLX)
NUMERIC		TOK(NUMERIC)
OF	       	TOK(OF)
ON	       	TOK(ON)
OPEN		TOK(OPEN)
OPTION		TOK(OPTION)
OR	       	TOK(OR)
ORDER		TOK(ORDER)
PRECISION	TOK(PRECISION)
PRIMARY		TOK(PRIMARY)
PRIVILEGES	TOK(PRIVILEGES)
PROCEDURE	TOK(PROCEDURE)
PUBLIC		TOK(PUBLIC)
REAL		TOK(REAL)
REFERENCES	TOK(REFERENCES)
ROLLBACK	TOK(ROLLBACK)
SELECT		TOK(SELECT) 
SET	        TOK(SET)
SMALLINT	TOK(SMALLINT)
SOME		TOK(SOME)
SQLCODE		TOK(SQLCODE)
TABLE		TOK(TABLE)
TO	       	TOK(TO)
UNION		TOK(UNION)
UNIQUE		TOK(UNIQUE)
UPDATE		TOK(UPDATE)
USER		TOK(USER)
VALUES		TOK(VALUES)
VIEW		TOK(VIEW)
WHENEVER	TOK(WHENEVER)
WHERE		TOK(WHERE)
WITH		TOK(WITH)
WORK		TOK(WORK)

 /* punctuation */

"="  |
"<>" |
"<"  |
">"  |
"<=" |
">=" TOK(COMPARISON)

[-+*/(),.;]	{  TOK(yytext[0]) }


	/* names */
[A-Za-z][A-Za-z0-9_]*	{ TOK(NAME) }

	/* parameters */
":"[A-Za-z][A-Za-z0-9_]* {
			return PARAMETER;
		}


  /* numbers */
[+-]?[0-9]+	|
[+-]?[0-9]+"."[0-9]* |
[+-]?"."[0-9]* {  TOK(INTNUM) }

(\+|-)?([0-9]+\.?[0-9]*|\.[0-9]+)([eE](\+|-)?[0-9]+)? { TOK(APPROXNUM) }

{quote} {BEGIN(inquote);}
<inquote>[^']*/' {BEGIN(endquote); TOK(STRING) }
<endquote>' {BEGIN(0);}

 /* @bug 1870. Since MySQL parser will error out all the unterminated string, we don't actually need it here. */
 /* '[^'\n]*$	{	dmlerror("Unterminated string"); } */

\n 	{ lineno++;}

[ \t\r]+ ;	/* white space */

"--".*	;	/* comment */
%%
using namespace dmlpackage;

void dmlerror(yyscan_t yyscanner, char const *s)
{
	printf("yyerror: %d: %s at %s\n", lineno, s, dmlget_text(yyscanner));
}

namespace dmlpackage {

static valbuf_t valbuf;

valbuf_t get_valbuffer(void)
{
	return valbuf;
}

/*
 * Called before any actual parsing is done
 */
void scanner_init(const char *str, yyscan_t yyscanner)
{
	size_t slen = strlen(str);
   scan_data* pScanData = (scan_data*)dmlget_extra(yyscanner);

	/*
	 * Might be left over after ereport()
	 */
   struct yyguts_t * yyg = (struct yyguts_t*)yyscanner; // needed for macro YY_CURRENT_BUFFER
	if (YY_CURRENT_BUFFER)
	   yy_delete_buffer(YY_CURRENT_BUFFER, yyscanner); 

	/*
	 * Make a scan buffer with special termination needed by flex.
	 */
	pScanData->scanbuf =  (char *)malloc(slen + 2);
	memcpy(pScanData->scanbuf, str, slen);
	pScanData->scanbuf[slen] = pScanData->scanbuf[slen + 1] = YY_END_OF_BUFFER_CHAR;
	pScanData->scanbufhandle = yy_scan_buffer(pScanData->scanbuf, slen + 2, yyscanner);

	BEGIN(INITIAL);

  
    pScanData->valbuf.clear();
}


/*
 * Called after parsing is done to clean up after scanner_init()
 */


void scanner_finish(yyscan_t yyscanner)
{
   char* str;
   scan_data* pScanData = (scan_data*)dmlget_extra(yyscanner);

   yy_delete_buffer((YY_BUFFER_STATE)pScanData->scanbufhandle, yyscanner);
   free(pScanData->scanbuf);
   unsigned int i;
   for(i=0; i<pScanData->valbuf.size(); i++) {
     str = pScanData->valbuf[i];
     if(str) {
        //std::cout << "valbuf:(" << str << ")" << std::endl;
        free(pScanData->valbuf[i]);
     }
   }
   pScanData->valbuf.clear();
}

char* scanner_copy (char *str, yyscan_t yyscanner)
{
  char* nv = strdup(str);
  if(nv)
    ((scan_data*)dmlget_extra(yyscanner))->valbuf.push_back(nv);
  return nv;
}

}
