-ifndef(_ESMB_LIB_HRL).
-define(_ESMB_LIB_HRL, true).

-define(elog(X,Y), error_logger:info_msg("*elog ~p:~p: " X,
					[?MODULE, ?LINE | Y])).

-define(BYTE, integer-unit:8).    % Nice syntactic sugar...

-define(PORT, 139).



%%% --------------------------------------------------------------------
%%% SMB stuff
%%% --------------------------------------------------------------------

%%% No.of bytes in SMB header preceeding 'WordCount'
-define(SMB_HEADER_LEN,          32).   

%%% SMB messages
-define(SMB_CREATE_DIRECTORY,    16#00).
-define(SMB_DELETE_DIRECTORY,    16#01).
-define(SMB_CLOSE,               16#04).
-define(SMB_DELETE,              16#06).
-define(SMB_CHECK_DIRECTORY,     16#10).
-define(SMB_COM_TRANSACTION,     16#25).
-define(SMB_OPEN_ANDX,           16#2d).
-define(SMB_READ_ANDX,           16#2e).
-define(SMB_WRITE_ANDX,          16#2f).
-define(SMB_COM_TRANSACTION2,    16#32).
-define(SMB_NEGOTIATE,           16#72).
-define(SMB_SESSION_SETUP_ANDX,  16#73).
-define(SMB_TREE_CONNECT_ANDX,   16#75).
-define(SMB_NT_CREATE_ANDX,      16#a2).

%%% SMB_COM_TRANSACTION2 subcommand codes
-define(SMB_TRANS2_FIND_FIRST2,  16#01).
-define(SMB_TRANS2_FIND_NEXT2,   16#02).

%%% Information level (e.g used by TRANS2_FIND_FIRST2
-define(SMB_INFO_STANDARD,                 1).
-define(SMB_FIND_FILE_DIRECTORY_INFO,      16#101).
-define(SMB_FIND_FILE_BOTH_DIRECTORY_INFO, 16#104).

%%% Subcommand codes for Transaction operations
-define(SUBCMD_TRANSACT_NM_PIPE,           16#26).
-define(SUBCMD_TRANSACT_WRITE_MAILSLOT,    1).


%%% NT_CREATE_ANDX flags
%%%
%%% Oplock levels:
%%%
%%%  0 - No oplock granted
%%%  1 - exclusive oplock granted
%%%  2 - batch oplock granted
%%%  3 - level II oplock granted
%%%  0x08 - Target of open must be directory
%%%
-define(NO_OPLOCK,          16#00).
-define(REQUEST_OPLOCK,     16#02).
-define(DIRECTORY_OPLOCK,   16#08).

%%% Access Mask Encoding
-define(AM_READ,          16#00000001).
-define(AM_WRITE,         16#00000002).
-define(AM_READ_CONTROL,  16#00020000).
-define(AM_GENERIC_READ,  16#80000000).

%%% File Share Access
-define(FILE_NO_SHARE,    16#00000000). % Prevents the file from being shared
-define(FILE_SHARE_READ,  16#00000001). % Others can open file for reading
-define(FILE_SHARE_WRITE, 16#00000002). % Others can open file for writing
-define(FILE_SHARE_RW,    16#00000003). 
-define(FILE_SHARE_DELETE,16#00000004). % Others can open file for delete
-define(FILE_SHARE_ALL,   16#00000007). 

%%% File attributes
-define(FILE_ATTR_NORMAL, 16#00000080). % Normal file
-define(FILE_ATTR_DIR,    16#00000010). % Directory

%%% Create Disposition, i.e action if file does/doesn't exist
-define(FILE_SUPERSEEDE,  16#00000000).
-define(FILE_OPEN,        16#00000001). % Open iff file exist, else fail
-define(FILE_CREATE,      16#00000002). % Create iff file don't exist, else fail
-define(FILE_OPEN_IF,     16#00000003). % Open iff file exist, else create
-define(FILE_OWRITE,      16#00000004). % Overwite iff file exist, else fail
-define(FILE_OWRITE_IF,   16#00000005). % Overwite iff file exist, else create

%%% Impersonation levels 
-define(SECURITY_ANONYMOUS,       0).
-define(SECURITY_IDENTIFICATION,  1).

%%% Create options. 
%%% Seems to be a bitmask defined as:
%%% 
%%% Bit X: Name - <Action if set>
%%% -----------------------------------------------
%%% Bit  0: Directory - File must be a directory
%%% Bit  1: Write Through - Writes need to flush buffers before completing
%%% Bit  2: Sequential Only - The file will be accessed sequentially
%%% Bit  3: -
%%% Bit  4: Sync I/O alert - Operations are syncronous
%%% Bit  5: Sync I/O non-alert - ?
%%% Bit  6: Non-Directory: File must not be a directory
%%% Bit  7: -
%%% Bit  8: -
%%% Bit  9: No EA Knowledge - The client don't understand ext.attriutes
%%% Bit 10: 8.3 Only - The client doesn't understand long file names
%%% Bit 11: Random Access - The file will be accessed randomly
%%% Bit 12: Delete On Close - The file should be deleted when closed
%%%
%%% A reasonable setting when open a file seem to be:
%%% Set Bit: 6,11  ==>  0x00000940  
%%%
%%% A reasonable setting when open a file seem to be:
%%% Set Bit: 0  ==>  0x00000001  
%%%
-define(FILE_OPEN_OPTIONS,  16#00000940).
-define(DIR_OPEN_OPTIONS,   16#00000001).


-define(FLAGS2_SUPPORT_SIGNATURES, 16#0004).
-define(FLAGS2_LONG_NAMES,         16#0001).
-define(FLAGS2_ERR_STATUS,         16#0000).  % DOS Error codes
-define(FLAGS2_NT_ERR_CODES,       16#4000).  % NT  Error codes
-define(FLAGS2_UNICODE,            16#8000).

-define(FLAGS2_NO_UNICODE,     16#7111).
-define(FLAGS2_UNSET_UNICODE(X), (X band ?FLAGS2_NO_UNICODE)).

%%%
%%% This is what we will negotiate as default.
%%%
-define(FLAGS2_NTLM, (?FLAGS2_LONG_NAMES bor
		      ?FLAGS2_SUPPORT_SIGNATURES bor
		      ?FLAGS2_UNICODE)).

-define(F2_USE_UNICODE(Pdu), 
	((Pdu#smbpdu.flags2 band ?FLAGS2_UNICODE) > 0)).

-define(F2_IS_NT_ERR_CODES(Pdu), 
	((Pdu#smbpdu.flags2 band ?FLAGS2_NT_ERR_CODES) > 0)).

%%% Create a new record and copy over important stuff!
-define(CP_PDU(R),(#smbpdu{
		  pid = R#smbpdu.pid,
		  uid = R#smbpdu.uid,
		  tid = R#smbpdu.tid,
		  fid = R#smbpdu.fid,
		  flags2 = R#smbpdu.flags2,
                  mac_key = R#smbpdu.mac_key,
                  signatures = R#smbpdu.signatures,
                  sign_seqno = R#smbpdu.sign_seqno,
                  samba2 = R#smbpdu.samba2,
                  netware = R#smbpdu.netware,
                  neg = R#smbpdu.neg})).

-define(SIGN_SMB(Pdu), (Pdu#smbpdu.signatures == true)).

%%% NB: Multi-byte values must be sent sent with the LSB first !!
-record(smbpdu, {
	  cmd,               % SMB command , 1 byte
	  eclass=0,          % error-class , 1 byte
	  ecode=0,           % error-code  , 2 bytes
	  flags=16#8,        % flags       , 1 byte  (path names are caseless)
	  flags2=?FLAGS2_LONG_NAMES,% flags2,2 bytes 
	  tid=0,             % Tree ID     , 2 bytes
	  pid=0,             % Process ID  , 2 bytes
	  uid=0,             % User ID     , 2 bytes
	  mid=0,             % Multiplex ID, 2 bytes
	  wc=0,              % Word count  , 1 byte
	  wp= <<>>,          % ParameterWords[WordCount] 
	  bc=0,              % Byte count  , 2 bytes
	  bf= <<>>,          % Buffer[ByteCount] 
	  %% --- Own, additional info
	  sub_cmd,           % Transaction sub command (if any)
	  fid,               % The file ID
	  file_size,         % The file size in bytes    
	  signatures=false,  % Enable security signatures of SMB msgs
	  sign_seqno=0,      % Signature request sequence number.
	  mac_key,           % Encryption key used for SMB signing
	  finfo=[],          % List of #file_info{} records
	  emsg="",           % Internal-error msg string
	  cont,              % Continuation: F()
	  samba2=false,      % Samba 2 == Old list share method
	  netware=false,     % NetWare == Old list share method
	  neg                % The #smb_negotiate_res{} record
	 }).

%%% Buffer value-tags
-define(BUF_FMT_DATA_BLOCK,     16#01).
-define(BUF_FMT_DIALECT,        16#02).
-define(BUF_PATHNAME,           16#03).
-define(BUF_FMT_ASCII,          16#04).
-define(BUF_FMT_VARIABLE_BLOCK, 16#05).

%% Character sets
-define(CSET_UCS2,         "UCS2").
-define(CSET_UCS2LE,       "UCS-2LE").
-define(CSET_UTF8,         "UTF-8").
-define(CSET_ASCII,        "ASCII").
-define(CSET_ISO_8859_1,   "ISO-8859-1").
-define(CSET_SJIS_WIN,     "SJIS-WIN").


-define(HEADER_SIZE, 100).        % max_data_sent = max_buffer_size - header_size
%-define(MAX_BUFFER_SIZE, 8192).  
-define(MAX_BUFFER_SIZE, 16644).  

%%% This record hold the negotiation result.
%%% (Add entries when more complex dialects are being implemented !)
-record(smb_negotiate_res, {
	  dialect_index,        % Example: ?PCNET_1_0
	  security_mode,        % PCNET_1_0 < Dialect <= LANMAN_2_1
	  encryption_key,       % PCNET_1_0 < Dialect <= LANMAN_2_1
	  srv_capabilities=0,
	  max_buffer_size=?MAX_BUFFER_SIZE,
	  samba2=false,
	  samba2_cset=?CSET_ASCII,
	  netware=false,
	  flags2                % copy of the flags2 field from the neg. PDU
	  }).

%%% SecurityMode flags when LANMAN is negotiated
-define(SECMODE_SHARE,     16#0).
-define(SECMODE_USER,      16#1).
-define(SECMODE_CHALLENGE, 16#2).
%%% SecurityMode flags when NT-LM-0.12 is negotiated
-define(SECMODE_SIGNATURE_ENABLED,   16#4).
-define(SECMODE_SIGNATURE_REQUIRED,  16#8).

-define(SCAP_UNICODE,  16#0004).

-define(USE_UNICODE(Neg),
	((Neg#smb_negotiate_res.srv_capabilities band ?SCAP_UNICODE) > 0)).

-define(DONT_USE_UNICODE(Neg), (not ?USE_UNICODE(Neg))).

%%% Apparently, Netware have the Unicode capability set to zero,
%%% but the flags2 bit indicates the use of Unicode... :-/
-define(USE_UNICODE_ANYWAY(Neg), 
	((Neg#smb_negotiate_res.flags2 band ?FLAGS2_UNICODE) > 0)).

-define(USE_ENCRYPTION(Neg), ((Neg#smb_negotiate_res.security_mode 
			       band ?SECMODE_CHALLENGE) > 0) ).

%%% As soon as the server has 'signatures' enabled we
%%% will sign the SMB PDU's (even though it may not be
%%% required).
-define(USE_SIGNATURES(Neg),
	((Neg#smb_negotiate_res.security_mode band 
	  ?SECMODE_SIGNATURE_ENABLED) > 0)).

%%% Add more dialects when we can support them.
%%% Make sure to not break the successive order of
%%% the dialects we are sending in the neg-req, so
%%% that we know which dialect that was choosen !
-define(PCNET_1_0,   0).    % PC NETWORK PROGRAM 1.0
-define(LANMAN_1_0,  1).    % LANMAN 1.0
-define(NT_LM_0_12,  2).    % NT LM 0.12

%%% Some tests for choosen dialect
-define(CORE_PROTOCOL(Neg), 
	(Neg#smb_negotiate_res.dialect_index == ?PCNET_1_0)).
-define(PRE_DOS_LANMAN_2_1(Neg), 
	(Neg#smb_negotiate_res.dialect_index =< ?LANMAN_1_0)).
-define(NTLM_0_12(Neg), 
	(Neg#smb_negotiate_res.dialect_index == ?NT_LM_0_12)).



%%% Session_Setup_AndX parameter values
-define(NoAndxCmd ,    16#FF).  % secondary (X) command, or none
-define(MaxMpxCount,   2).      % ? ,max multiplexed pending req.
-define(VcNumber,      2325).   % ? 

%%% Session_Setup_AndX capabilities
-define(CAP_UNICODE,   16#0004).

%%% Tree-Connect-AndX service types
%%% (NB: These strings should not be sent in Unicode format)
-define(SERVICE_DISK_SHARE, "A:").
-define(SERVICE_NAMED_PIPE, "IPC").
-define(SERVICE_ANY_TYPE,   "?????").

%%% Share type info returned from "list shares" request
-define(SHARETYPE_DISKTREE,   0).
-define(SHARETYPE_PRINTQ,     1).
-define(SHARETYPE_DEVICE,     2).
-define(SHARETYPE_IPC,        3).

-record(share_info, {
	  name,        % The share name
	  type         % ?SHARETYPE_xxxx
	  }).

%%% Server type bit fields (see also C.Hertel's book)
-define(SV_TYPE_ALL,           16#FFFFFFFF). % to query for all servers
-define(SV_TYPE_DOMAIN_ENUM,   16#80000000).
%%% ...lots of more bit fields....
-define(SV_TYPE_SERVER,        16#00000002). % offers SMB file service
-define(SV_TYPE_WORKSTATION,   16#00000001). 

-record(server_info, {
	  name,        % The share name
	  type         % ?SV_TYPE_xxxx
	  }).

%%% User info
-define(DEFAULT_WORKGROUP,  "WORKGROUP").
-define(DEFAULT_CHARSET,    "ASCII").
-record(user, {
	  pw,
	  name,
	  primary_domain = ?DEFAULT_WORKGROUP,
	  native_os      = "Linux",
	  native_lanman  = "esmb",
	  charset        = ?DEFAULT_CHARSET,
	  auth_domain    = ?DEFAULT_WORKGROUP,
	  host,
	  port           = ?PORT,
	  share          = "",
	  path           = "",
	  context        = ""
	  }).


%%% File info
-record(file_info, {
	  name,
	  size,
	  attr,
	  date_time,     % a #dt{} record
	  resume_key,
	  data_len = 0,  % # of bytes in data
	  data = [],     % an I/O list
	  offset = 0,    % offset were to start file operation
	  max_count = ?MAX_BUFFER_SIZE, % max # of bytes to return
	  min_count = ?MAX_BUFFER_SIZE  % min # of bytes to return
	 }).

%%% Date/Time info
-record(dt, {
	  creation_date,
	  creation_time,
	  last_access_date,
	  last_access_time,
	  last_write_date,
	  last_write_time
	 }).


-define(DIR_FLAG,      16#10).
-define(HIDDEN_FLAG,   16#2).

-define(IS_DIR(A), ((A band ?DIR_FLAG) > 0)).
-define(IS_HIDDEN(A), ((A band ?HIDDEN_FLAG) > 0)).

%%% Result from find first/next operation
-record(find_result, {
	  sid,         % Search handle
	  eos = false, % End of search 
	  finfo = []   % list_of( #file_info{} )
	 }).

%%% Error class
-define(INTERNAL,    -1).     % Internal esmb error
-define(SUCCESS,     0).      % The request was successful
-define(ERRDOS,      16#01).  % Error is from core DOS OS set
-define(ERRSRV,      16#02).  % Error generated by srv netw. file manager
-define(ERRHRD,      16#03).  % Error is hardware error
-define(ERRCMD,      16#ff).  % Command was not in SMB format
-define(ERRNT,       16#aa).  % Our mark for repr. NT-error codes.

%%% ERRDOS error codes
%-define(INTERNAL,    -1).    % same as above...
-define(ERRbadfunc,  1).      % Invalid function
-define(ERRbadfile,  2).      % File not found
-define(ERRbadpath,  3).      % Directory invalid
-define(ERRnofids,   4).      % Too many open files
-define(ERRnoaccess, 5).      % Access denied
-define(ERRnoshare,  16#43).  % Share does not exist
-define(ERRfileexist,16#50).  % File in operation already exists
-define(ERRdirnotempty,16#91).% Directory not empty (just a guess!!)

%%% ERRSRV error codes
%-define(INTERNAL,    -1).    % same as above...
-define(ERRSbadpw,      2).   % Bad password
-define(ERRSaccess,     4).   % Insufficient access rights
-define(ERRSinvtid,     5).   % Invalid TID (Transaction ID)
-define(ERRSinvnetname, 6).   % Invalid network name in tree connect

%%% ERRNT error codes
%-define(INTERNAL,    -1).    % same as above...
-define(ERRNTfileisdir, 16#c00000ba). % File is directory
	

%%% Gregorian second from year 0 to 1601 AD
%%%  calendar:datetime_to_gregorian_seconds({{1601,1,1},{0,0,0}}).
-define(GREG_SEC_0_TO_1601,  50522745600).

-ifdef(debug).
-define(dbg(Fstr, Args), io:format(Fstr, Args)).
-else.
-define(dbg(Fstr, Args), true).
-endif.

-endif.
