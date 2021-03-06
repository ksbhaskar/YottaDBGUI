	;								
	; Copyright (c) 2017-2018 YottaDB LLC. and/or its subsidiaries.	
	; All rights reserved.						
	;								
	;	This source code contains the intellectual property	
	;	of its copyright holder(s), and is made available	
	;	under a license.  If you do not know the terms of	
	;	the license, please stop and do not read further.	
	;	

save ;;save the new GDE local state obtained from the client
handle(ARGS,BODY,RESULT)
  ;
  new JSON,RSLT,ERR
  do DECODE^VPRJSON("BODY","JSON","ERR")
  new verifySaveStatus
  new nams,regs,segs,tmpacc,tmpreg,tmpseg,gnams,create,file,useio,debug,io,inst
  merge nams=JSON("nams") ;NOTE: the object sent from the client doesn't contain the nams/regs/segs count component stored in the unsubscripted spot
                          ;i.e. while GDE has locals like nams=2, regs=2, segs=1 storing the num of names/regions/segments, the client doesn't send that data back
                          ;after changes on the client side which may change those numbers
  ;convert all region data in nams to uppercase - should be enforced client-side, but this is for safety
  set x="" for  set x=$order(nams(x)) quit:x=""  set nams(x)=$$FUNC^%UCASE(nams(x))
  merge regs=JSON("regs")
  ;convert all first-level subscripts of regs to uppercase - they should already all be uppercase (enforced on client side), but this is for safety
  set next=$order(regs("")) for  set x=next quit:x=""  do
  . set next=$order(regs(x))
  . kill temp
  . merge temp=regs(x)
  . set temp("DYNAMIC_SEGMENT")=$$FUNC^%UCASE(temp("DYNAMIC_SEGMENT")) ;part of converting all segments to uppercase
  . kill regs(x)
  . merge regs($$FUNC^%UCASE(x))=temp
  ;if $ZJOBEXAM() ;DEBUG - TODO remove; this line not getting hit when re-saving unmodified default directory - why?
  merge segs=JSON("segs")
  ;convert all first-level subscripts of segs to uppercase - they should already all be uppercase (enforced on client side), but this is for safety
  set next=$order(segs("")) for  set x=next quit:x=""  do
  . set next=$order(segs(x))
  . kill temp
  . merge temp=segs(x)
  . kill segs(x)
  . merge segs($$FUNC^%UCASE(x))=temp
  merge tmpacc=JSON("tmpacc")
  merge tmpreg=JSON("tmpreg")
  merge tmpseg=JSON("tmpseg")
  merge gnams=JSON("gnams")
  merge create=JSON("create")
  merge file=JSON("file")
  merge useio=JSON("useio") ;2018-03 AKB - do I need to pass this between the client and server? looks like it's just "io"
  merge debug=JSON("debug")
  merge io=JSON("io")
  merge inst=JSON("inst")
  do GDEINIT^GDEINIT
  do GDEMSGIN^GDEMSGIN
  ;do NAME^GDEADD,REGION^GDEADD,SEGMENT^GDEADD ;phasing this out in favor of add2nams^gdemap()
  ;
  ;loop over the bindings in nams and call add2nams^GDEMAP() for each range-type name in order to properly structure the nams data tree to handle subscripted ranges
  ;nams(x) needs to be killed before add2nams() is called, since add2nams() quits if there is data there
  set next=$order(nams("")) for  set x=next quit:x=""  do
  . set next=$order(nams(x))
  . if x?1.A1"("1.N1":"1.N1")" do  ;IMPORTANT TODO: is this true iff x is a range-typed name? what happens when the left side number is == or > the right? are these checks handled elsewhere in the GDE code? gdeparse.m? currently A>B range subscripts break the gld
  . . new reg set reg=nams(x)
  . . kill nams(x)
  . . new namPlusCaret set namPlusCaret="^"_x ;add2nams^GDEMAP() expects a leading caret and removes the first character in accordance with that assuption
  . . do add2nams^GDEMAP(namPlusCaret,reg,"RANGE")
  i $$ALL^GDEVERIF,$$GDEPUT^GDEPUT do  
  . s verifySaveStatus="success"
  . ;
  . ; new $etrap
  . ; set $etrap="zshow ""*"":mysavetrap"
  . ; do DUMP^GDE(.getMapData)
  . ;
  . ;
  . ;
  . kill getMapData
  . merge getMapData("nams")=nams
  . merge getMapData("regs")=regs
  . merge getMapData("segs")=segs
  . zkill getMapData("nams"),getMapData("regs"),getMapData("segs")
  .
  . ;stats db cleanup for nams - if getMapData("nams") contains a binding from a name to a region where the region has lowercase characters, delete the binding
  . set next=$order(getMapData("nams","")) for  set x=next quit:x=""  do
  . . set next=$order(getMapData("nams",x))
  . . if getMapData("nams",x)'=$$FUNC^%UCASE(getMapData("nams",x)) kill getMapData("nams",x)
  . 
  . ;stats db cleanup for regs and segs - delete getMapData("regs",x) and getMapData("segs",x) where x is a region or segment that has lowercase characters
  . set next=$order(getMapData("regs","")) for  set x=next quit:x=""  do
  . . set next=$order(getMapData("regs",x))
  . . if x'=$$FUNC^%UCASE(x) kill getMapData("regs",x)
  . set next=$order(getMapData("segs","")) for  set x=next quit:x=""  do
  . . set next=$order(getMapData("segs",x))
  . . if x'=$$FUNC^%UCASE(x) kill getMapData("segs",x)
  e  s verifySaveStatus="failure",getMapData="" ;null value instead of empty string for getMapData?
  set RSLT("verifySaveStatus")=verifySaveStatus
  merge RSLT("getMapData")=getMapData
  do ENCODE^VPRJSON("RSLT","RESULT","ERR")
  quit ""
