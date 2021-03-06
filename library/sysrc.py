#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import stat
import platform
import re

DOCUMENTATION = """
---
module: sysrc
author: Matthew Pherigo
short_description: Manage FreeBSD's rc.conf files through sysrc. Create file if
  not present.
requirements: [ FreeBSD, sysrc ]
version_added: '0.1'
options:
  line:
    required: false
    description: a single rc.conf key-value pair, such as 'sendmail_enable="NO"'
  key:
    required: false
    aliases: [ option, name ]
    description:
    - the key part of a key-value pair to go in a conf file
  value:
    required: false
    aliases: setting
    description:
    - the value to the preceding key-value. Required for C(state=present)
  state:
    required: false
    choices: [ present, absent ]
    default: "present"
    aliases: []
    description:
    - Whether the line should be there or not
  path:
    required: false
    default: "/etc/rc.conf.local"
    aliases: [ dest ]
    description:
    - Specify the file that sysrc should operate on. Created if not present.
"""

EXAMPLES = r"""
- sysrc: line='ezjail_enable="YES"'
    state=present

- sysrc: key=sshd_enable
    value=YES
    state=present

- sysrc: key=sendmail_enable
    state=absent
"""

class Sysrc(object):

  def check_file(self, path): # See if file is writeable or needs to be created
    try:
      path = os.path.abspath(path)
      if not os.path.isfile(path):
        with open(path, 'w') as f:
          f.writelines('# {}: Created by the sysrc Ansible module\n\n'.format(path))
        if path == '/etc/rc.conf.local':
          st = os.stat('/etc/rc.conf')
          os.chown(path, st.st_uid, st.st_gid)
          os.chmod(path, stat.S_IMODE(st.st_mode))
    except:
      self.module.fail_json(msg="Something failed while making the file!\r",
          errortype      = '{}'.format(sys.exc_info()[0]),
          errorvalue     = '{}'.format(sys.exc_info()[1]),
          errortraceback = '{}'.format(sys.exc_info()[2]),
          )
    return path

  def __init__(self, module):
    self.module = module
    try: # Find sysrc
      self.sysrc_path = self.module.get_bin_path('sysrc', True)
    except:
      self.module.fail_json(msg="Could not find the path for sysrc!")
    self.state = module.params['state']
    self.key   = module.params['key']
    self.value = module.params['value']
    self.line  = module.params['line']
    print self.module.jsonify(module.params['path'])
    try:
      self.path = self.check_file(module.params['path'])
      if not os.path.isfile(self.path):
        self.module.fail_json(msg='Path returned doesn\'t real', path=self.path)
    except:
      self.module.fail_json(msg='Could not find or create {}'.format(module.params['path']),
        errortype      = '{}'.format(sys.exc_info()[0]),
        errorvalue     = '{}'.format(sys.exc_info()[1]),
        errortraceback = '{}'.format(traceback.format_tb(sys.exc_info()[2]))
        )
    self.result = {}
    rc     = None
    out    = ''
    err    = ''

    if self.line:
      self.key, self.value = re.split('\=', self.line, maxsplit=1)

    if self.state == 'present':
      if not self.line:
        if not self.value:
          self.module.fail_json(msg="You must specify a key and value for 'state=present'")
        if not self.key:
          self.module.fail_json(msg="You must specify a key and value for 'state=present'")
    elif self.state == 'absent':
      if not self.line:
        if not self.key:
          self.module.fail_json(msg="You must specify a key for 'state=absent'")

    cmd = [
        self.sysrc_path,
        '-f',
        self.path
        ]
    if self.state == 'absent':
      cmd.insert(1, '-x')
      cmd.append(self.key)
    else:
      cmd.insert(1, '-n')
      cmd.append(self.key + '=' + self.value)
    try:
      (rc, out, err) = self.module.run_command(cmd)
    except:
      self.module.fail_json(msg="run_command failed!", rc=rc, out=out, err=err, cmd=cmd)
    if rc is not None and rc != 0 and self.state != 'absent':
      self.module.fail_json(msg="Return code not 0!", err=err, cmd=cmd, rc=rc)

    if self.state == 'present':
      nochange = re.match('{} -> {}'.format(self.value, self.value), out)
      if nochange:
        self.result['changed'] = False
      else:
        self.result['changed'] = True
      if err:
        self.result['stderr'] = err
        self.result['failed'] = True
        self.module.fail_json(msg=err, cmd=cmd, rc=rc)
    else:
      if rc is not None and rc == 0:
        self.result['changed'] = True
      elif rc == 1:
        self.result['changed'] = False
      else:
        self.module.fail_json(msg=err, cmd=cmd, rc=rc)

    module.exit_json(**self.result)

def main():
  module = AnsibleModule(
      argument_spec = dict(
        state       = dict(default='present', choices=['present', 'absent'], type='str'),
        key         = dict(aliases=['name', 'option'], type='str'),
        value       = dict(aliases=['setting'], type='str'),
        path        = dict(aliases=['file'], default='/etc/rc.conf.local', type='str'),
        line        = dict(type='str')
        ),
      supports_check_mode=False
      )

  sysrc = Sysrc(module)

from ansible.module_utils.basic import *
main()
