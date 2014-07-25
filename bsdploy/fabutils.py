from fabric.api import env
from fabric.contrib.project import rsync_project as _rsync_project


def rsync_project(*args, **kwargs):
    additional_args = []
    ssh_info = env.instance.init_ssh_key()
    for key in ssh_info:
        if key[0].isupper():
            additional_args.append('-o')
            additional_args.append('%s="%s"' % (key, ssh_info[key].replace('"', '\"')))
    kwargs['ssh_opts'] = '%s %s' % (kwargs.get('ssh_opts', ''), ' '.join(additional_args))
    _rsync_project(*args, **kwargs)
