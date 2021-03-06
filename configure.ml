let config_mk = "config.mk"

let find_ocamlfind verbose name =
  let found =
    try
      let (_: string) = Findlib.package_property [] name "requires" in
      true
    with
    | Not_found ->
      (* property within the package could not be found *)
      true
    | Findlib.No_such_package(_,_ ) ->
      false in
  if verbose then Printf.fprintf stderr "querying for ocamlfind package %s: %s" name (if found then "ok" else "missing");
  found

(* Configure script *)
open Cmdliner

let bindir =
  let doc = "Set the directory for installing binaries" in
  Arg.(value & opt string "/usr/bin" & info ["bindir"] ~docv:"BINDIR" ~doc)

let libexecdir =
  let doc = "Set the directory for installing helper executables" in
  Arg.(value & opt string "/usr/lib/xapi" & info ["libexecdir"] ~docv:"LIBEXECDIR" ~doc)

let etcdir =
  let doc = "Set the directory for installing configuration files" in
  Arg.(value & opt string "/etc" & info ["etcdir"] ~docv:"ETCDIR" ~doc)

let info =
  let doc = "Configures a package" in
  Term.info "configure" ~version:"0.1" ~doc 

let output_file filename lines =
  let oc = open_out filename in
  let lines = List.map (fun line -> line ^ "\n") lines in
  List.iter (output_string oc) lines;
  close_out oc

let configure bindir libexecdir etcdir =

  Printf.printf "Configuring with:\n\tbindir=%s\n\tlibexecdir=%s\n\tetcdir=%s\n" bindir libexecdir etcdir;

  let xcp = find_ocamlfind false "xcp" in
  let xenstore_transport = find_ocamlfind false "xenstore_transport" in
  let xenstore = find_ocamlfind false "xenstore" in
  let tapctl = find_ocamlfind false "tapctl" in
  let enable_xenserver = xcp && xenstore_transport && xenstore && tapctl in
  let lines = 
    [ "# Warning - this file is autogenerated by the configure script";
      "# Do not edit";
      Printf.sprintf "BINDIR=%s" bindir;
      Printf.sprintf "LIBEXECDIR=%s" libexecdir;
      Printf.sprintf "ETCDIR=%s" etcdir;
      Printf.sprintf "ENABLE_XENSERVER=--%sable-xenserver" (if enable_xenserver then "en" else "dis");
    ] in
  output_file config_mk lines;
  let lines =
    [ "bin: [";
      "  \"main.native\" { \"vhd-tool\" }";
    ] @ (if enable_xenserver
         then [ "  \"sparse_dd.native\" { \"sparse_dd\" }" ]
         else []) @ [
      "]";
      "man: [";    
      "  \"vhd-tool.1\" { \"vhd-tool.1\" }";
    ] @ (if enable_xenserver
         then [ "  \"sparse_dd.1\" { \"sparse_dd.1\" }" ]
         else []) @ [
      "]";  
    ] in
  output_file "vhd-tool.install" lines

let configure_t = Term.(pure configure $ bindir $ libexecdir $ etcdir )

let () = 
  match 
    Term.eval (configure_t, info) 
  with
  | `Error _ -> exit 1 
  | _ -> exit 0
