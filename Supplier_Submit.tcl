# File      : Supplier_Submit_GUI.tcl
# Date      : 2018.3.7
# Created by: HXM
# Function  : 1.生成用户界面
#             2.提供界面按钮功能

#引用
package require Tk
package require http

set libDir [file join [file dir [info script]] "lib"]
catch {source "$libDir/json.tcl"}

# 定义变量
catch {namespace delete ::MeshSubmit}
namespace eval ::MeshSubmit {
	#GUI Related Variables
	variable mainGUI;
	set mainGUI .mainGUI;
	
	#http site
	variable url;
	set url "http://caeapp.patac.shanghaigm.com/vi_supplier/api.php?func="
	
	#project_dict
	variable project_dict;
	
	#prjnode_dict
	variable prjnode_dict;
	
	#submit info needed
	variable submit_dict;
}

# ::MeshSubmit::InitSubmitDict
# 	Initialzie submit_dict
# arguments:
#	
# output:
#	0  success
#   1 failed
proc ::MeshSubmit::InitSubmitDict {} {
	variable submit_dict;
	#default time
	set hours 8;
	#default description
	set jobinfo \
	"Mesh the model with 5mm target size,3mm minimum size. And keep the model struct, put elements to original GEOM comp." 
	#作业提交目录
	set sup_folder "//wishn00111.patac.shanghaigm.com/cae_transfer/01_JobInput";
	# 最迟完成时间（格式YYYY-MM-DD HH:MM:SS）,现在按照3天设置
	set days 3
	set task_deadline [clock format [expr [clock seconds]+86400*$days] -format "%Y-%m-%d %H:%M:%S"]
	#status设置
	set status 2
	#提交类型，0网格，1分析
	set type 0
	
	set submit_dict [dict create uid "" \
	pwd "" \
	task_name "" \
	task_detail $jobinfo \
	project_id "" \
	prjnode_id "" \
	task_expect_hours $hours \
	task_deadline $task_deadline \
	filepath_input $sup_folder \
	filename_input "" \
	status 2 \
	type 0 \
	supplier_id 0]
	
	return 
}

# ::MeshSubmit::GetUserPW
# 	check if User and PW exists
#	update them to submit_config 
# arguments:
#
# output:
#	updated submit_config
#   0:success
#   1:Failed
proc ::MeshSubmit::GetUserPW {} {
	variable submit_dict;
	set acc [$::MeshSubmit::userentry get]
	set pw [$::MeshSubmit::pwentry get]
	if {$acc!=""&&$pw!=""} {
		dict set submit_dict uid $acc
		dict set submit_dict pwd $pw
		return 0
	} else {
		tk_messageBox -title "Mesh Submit" -icon error -message "Supplier System Username/Password not ready"
		return 1
	}
}

# ::MeshSubmit::SetTaskName
# 	Get TaskName from model
# arguments:
#	
# output:
#	0  success
#   1 failed
proc ::MeshSubmit::SetTaskName {} {
	variable submit_dict;
	
	set name [hm_info currentfile]
	if {$name!=""} {
		dict set submit_dict task_name [file tail [file rootname $name]]
		return 0
	} else {
		tk_messageBox -title "Mesh Submit" -icon error \
		-message "Please Save .hm Model first"
		return 1
	}
}

# ::MeshSubmit::SetFilePath
# 	copy file to Remote and 
#	Set Remote File Path
#   set Remote file name
# arguments:
#	
# output:
#	0  success
#   1 failed
proc ::MeshSubmit::SetFilePath {} {
	variable submit_dict;
	
	set name [hm_info currentfile]
	hm_answernext yes
	*writefile "$name" 1
	
	set remote_path [dict get $submit_dict filepath_input]
	set prefix [file tail [file rootname $name]]
	set postfix [clock format [clock seconds] -format "_%Y%m%d%H%M%S"]
	set remote_path "$remote_path/$prefix$postfix"
	
	if {[catch {file mkdir "$remote_path"}]!=0} {
		return 1
	}
	
	if {[catch {file copy -force $name $remote_path}]!=0} {
		return 1
	}
	
	dict set submit_dict filepath_input $remote_path
	dict set submit_dict filename_input [file tail $name]
	return 0
}

# ::MeshSubmit::SetProjectID
# 	Get ProjectID from combo
# arguments:
#	
# output:
#	0  success
#   1 failed
proc ::MeshSubmit::SetProjectID {} {
	variable submit_dict;
	variable project_dict;
	
	set proj [$::MeshSubmit::projcombo get]
	dict for {name value} $project_dict {
		if {[string equal $proj $value]==1} {
			dict set submit_dict project_id $name
			break
		} else {
			continue
		}
	}
	
	if {[dict get $submit_dict project_id]==""} {
		return 1
	} else {
		return 0
	}
}

# ::MeshSubmit::SetNodeID
# 	Get Project Node ID from combo
# arguments:
#	
# output:
#	0  success
#   1 failed
proc ::MeshSubmit::SetNodeID {} {
	variable submit_dict;
	variable prjnode_dict;
	
	set node [$::MeshSubmit::gatecombo get]
	dict for {name value} $prjnode_dict {
		if {[string equal $node $value]==1} {
			dict set submit_dict prjnode_id $name
			break
		} else {
			continue
		}
	}
	
	if {[dict get $submit_dict  prjnode_id]==""} {
		return 1
	} else {
		return 0
	}
}

# ::MeshSubmit::GetComboList
# 	Get Project from server
#   update the dropdown list
# arguments:
#	combo_handle: path name of combo
#	func: func type, "project" "prjnode" "supplier" is valid, currently first two is supported
# output:
#	updated ComboList
#   0 success
proc ::MeshSubmit::GetComboList {combo_handle func url} {
	# 获取节点列表
	variable submit_dict;
	variable project_dict;
	variable prjnode_dict;
	
	set uid [dict get $submit_dict uid];
	set pwd [dict get $submit_dict pwd];
	set token [http::geturl $url$func -query [http::formatQuery uid $uid pwd $pwd]]
	set data [json::parse [http::data $token]]
	http::cleanup $token
	
	if {[dict get $data "status"] != 0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt [dict get $data "msg"]
		return -code error "Error: can not get $func list"
	} else {
		set tmp [dict get $data "msg"]
		switch $func {
			"project" {
				set project_dict $tmp;
				set droplist "";
				dict for {name value} $project_dict {
					lappend droplist $value
				}
			}
			"prjnode" {
				set prjnode_dict $tmp;
				set droplist "";
				dict for {name value} $prjnode_dict {
					lappend droplist $value
				}
			}
		}
		$combo_handle configure -value $droplist
		$combo_handle set [lindex $droplist 0]
		
		return 0
	}
}

# ::MeshSubmit::UpdateTxt
# 	update the txt widget
# arguments:
#	txt_handle: path name of txt
#   content: strings to insert
# output:
#	updated txt widget
proc ::MeshSubmit::UpdateTxt {txt_handle content} {
	$txt_handle configure -state normal
	set cur_time [clock format [clock seconds] -format "%Y-%b-%d %H:%M:%S"]
	$txt_handle insert end "$cur_time,$content"
	$txt_handle configure -state disabled
}

# ::MeshSubmit::ClearTxt
# 	Clear the txt widget
# arguments:
#	txt_handle: path name of txt
#   content: strings to insert
# output:
#	clear the txt
proc ::MeshSubmit::ClearTxt {txt_handle} {
	$txt_handle configure -state normal
	$txt_handle delete 0.0 end
	$txt_handle configure -state disabled
}

# ::MeshSubmit::Login
# 	Get Username/Password
#	Update dropdown list
#   insert default job info
# arguments:
#	combo_handle: path name of combo
#	func: func type, "project" "prjnode" "supplier" is valid
# output:
#	0  success
proc ::MeshSubmit::Login {} {
	variable submit_dict;
	#获取用户名/密码
	::MeshSubmit::InitSubmitDict
	::MeshSubmit::ClearTxt $::MeshSubmit::jobtxt
	set flag [::MeshSubmit::GetUserPW]
	if {$flag==0} {
		::MeshSubmit::GetComboList $::MeshSubmit::projcombo project $::MeshSubmit::url
		::MeshSubmit::GetComboList $::MeshSubmit::gatecombo prjnode $::MeshSubmit::url
		$::MeshSubmit::supptxt insert 0.0 [dict get $submit_dict task_detail]
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Login Success..\n"
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "\nLogin Failed....Exiting\n"
		return 1
	}
}

# ::MeshSubmit::Submit
# 	Update all submit_dict value
#	copy file to remote
#	submit to web
# arguments:
#	combo_handle: path name of combo
#	func: func type, "project" "prjnode" "supplier" is valid
# output:
#	0 success
#   1 failed
proc ::MeshSubmit::Submit {} {
	variable submit_dict;
	variable url
	
	#更新TaskName
	if {[catch ::MeshSubmit::SetTaskName]==0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Job Name Set..\n"
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Job Name not Set..Exiting\n"
		return 1
	}
	
	#更新Project
	if {[catch ::MeshSubmit::SetProjectID]==0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Project Set..\n"
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Project not Set..Exiting\n"
		return 1
	}
	
	#更新Gate
	if {[catch ::MeshSubmit::SetNodeID]==0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Gate Set..\n"
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Gate not Set..Exiting\n"
		return 1
	}
	
	#更新Folder信息，并copy文件
	if {[catch ::MeshSubmit::SetFilePath]==0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "File Copied and Path Set..\n"
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "File not Copied or Path not Set..Exiting\n"
		return 1
	}
	
	#提交作业
	set func "addtask"
	set token [http::geturl $url$func -query [http::formatQuery {*}$submit_dict]]
	set data [json::parse [http::data $token]]
	http::cleanup $token
	if {[dict get $data "status"] != 0} {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt [dict get $data "msg"]
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "\nJob Submit Failed..Exiting\n"
		return 1
	} else {
		::MeshSubmit::UpdateTxt $::MeshSubmit::jobtxt "Job Submit Succeed..Done\n"
		return 0
	}
}

# ::MeshSubmit::CreateGUI
# Create mainGUI
# arguments:
#	description: 任务描述
# output:
#	Main GUI of Submission
proc ::MeshSubmit::CreateGUI {} {
	catch {destroy $::MeshSubmit::mainGUI}
	toplevel $::MeshSubmit::mainGUI
	wm title $::MeshSubmit::mainGUI "Mesh Submission"
	wm attributes $::MeshSubmit::mainGUI -topmost 1
	#Login frame
	set loginfrm [ttk::labelframe $::MeshSubmit::mainGUI.loginfrm -padding 10 -text "Login"]
	set userlab [ttk::label $loginfrm.userlab -text "Account:"]
	set ::MeshSubmit::userentry [ttk::entry $loginfrm.userentry -width 15]
	set pwlab [ttk::label $loginfrm.pwlab -text "Password:"]
	set ::MeshSubmit::pwentry [ttk::entry $loginfrm.pwentry -show * -width 15]
	set loginbtn [ttk::button $loginfrm.loginbtn -width 15 -text "Login" \
	-command "::MeshSubmit::Login"]
	
	#Jobinfo frame
	set jobfrm [ttk::labelframe $::MeshSubmit::mainGUI.jobfrm -padding 2 -text "Job Info"]
	set ::MeshSubmit::supptxt [text $jobfrm.supptxt -height 3 -width 45]
	set projlab [ttk::label $jobfrm.projlab -text "Project:"]
	set ::MeshSubmit::projcombo [ttk::combobox $jobfrm.projcombo -state readonly -width 10]
	set gatelab [ttk::label $jobfrm.gatelab -text "Gate:"]
	set ::MeshSubmit::gatecombo [ttk::combobox $jobfrm.gatecombo -state readonly -width 10]
	set submitbtn [ttk::button $jobfrm.submitbtn -width 15 -text "Submit" \
	-command "::MeshSubmit::Submit"]
	
	#Job status Text Frame
	set txtfrm [ttk::labelframe $::MeshSubmit::mainGUI.txtfrm -padding 10 -text "Job Status"]
	set ::MeshSubmit::jobtxt [text $txtfrm.jobtxt -yscrollcommand [list $txtfrm.scroll set] \
	-setgrid 1 -height 10 -state disabled]
	set scrollbar [scrollbar $txtfrm.scroll -command [list $txtfrm.jobtxt yview]]
	
	#buttom buttons
	set btnfrm [ttk::frame $::MeshSubmit::mainGUI.btnfrm -padding 2]
	set closebtn [ttk::button $btnfrm.closebtn -width 15 -text "Close" -command {destroy $::MeshSubmit::mainGUI}]
	
	#griding loginfrm
	grid $loginfrm -row 0 -column 0 -sticky wn -pady 5 -padx 5
	grid $userlab -row 0 -column 0 -sticky w -pady 5 -padx 5
	grid $::MeshSubmit::userentry -row 0 -column 1 -sticky w -pady 5 -padx 5
	grid $pwlab -row 1 -column 0 -sticky w -pady 5 -padx 5
	grid $::MeshSubmit::pwentry -row 1 -column 1 -sticky w -pady 5 -padx 5
	grid $loginbtn -row 2 -column 1 -pady 5 -padx 5
	#griding jobfrm
	grid $jobfrm  -row 0 -column 1 -sticky w -pady 2 -padx 5
	grid $projlab -row 0 -column 0 -sticky w -pady 2 -padx 5
	grid $::MeshSubmit::projcombo -row 0 -column 1 -sticky w -pady 2 -padx 5
	grid $gatelab -row 0 -column 2 -sticky w -pady 2 -padx 5
	grid $::MeshSubmit::gatecombo -row 0 -column 3 -sticky w -pady 2 -padx 5
	grid $::MeshSubmit::supptxt -row 1 -columnspan 4 -sticky w -pady 2 -padx 5
	grid $submitbtn -row 2 -column 3 -sticky w -pady 5 -padx 5
	#griding txtfrm
	grid $txtfrm -row 1 -columnspan 2 -sticky w -pady 5 -padx 5
	pack $scrollbar -side right -fill y
	pack $::MeshSubmit::jobtxt -expand yes -fill both
	#griding btnfrm
	grid $btnfrm -row 2 -column 1 -sticky w -pady 5 -padx 5
	grid $closebtn -row 0 -column 0 -sticky e -pady 5 -padx 5
}
::MeshSubmit::CreateGUI