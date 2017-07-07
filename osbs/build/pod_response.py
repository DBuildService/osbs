"""
Copyright (c) 2015, 2017 Red Hat, Inc
All rights reserved.

This software may be modified and distributed under the terms
of the BSD license. See the LICENSE file for details.
"""
from __future__ import print_function, absolute_import, unicode_literals

import logging

from osbs.utils import graceful_chain_get


logger = logging.getLogger(__name__)


class PodResponse(object):
    """
    Wrapper for JSON describing build pod
    """

    def __init__(self, pod):
        """
        :param request: http.Request
        """
        self._json = pod

    @property
    def json(self):
        return self._json

    def get_container_image_ids(self):
        """
        Find the image IDs the containers use.

        :return: dict, image tag to docker ID
        """

        statuses = graceful_chain_get(self.json, "status", "containerStatuses")
        if statuses is None:
            return {}

        def remove_prefix(image_id, prefix):
            if image_id.startswith(prefix):
                return image_id[len(prefix):]

            return image_id

        return dict([(status['image'], remove_prefix(status['imageID'],
                                                     'docker://'))
                     for status in statuses])

    def get_failure_reason(self):
        """
        Find the reason a pod failed

        :return: dict, which will always have key 'reason':
                 reason: brief reason for state
                 containerID (if known): ID of container
                 exitCode (if known): numeric exit code
        """

        REASON_KEY = 'reason'
        CID_KEY = 'containerID'
        EXIT_KEY = 'exitCode'

        pod_status = self.json.get('status', {})
        statuses = pod_status.get('containerStatuses', [])

        # Find the first non-zero exit code from a container
        # and return its 'message' or 'reason' value
        for status in statuses:
            try:
                terminated = status['state']['terminated']
                exit_code = terminated['exitCode']
                if exit_code != 0:
                    reason_dict = {
                        EXIT_KEY: exit_code,
                    }

                    if 'containerID' in terminated:
                        reason_dict[CID_KEY] = terminated['containerID']

                    for key in ['message', 'reason']:
                        try:
                            reason_dict[REASON_KEY] = terminated[key]
                            break
                        except KeyError:
                            continue
                    else:
                        # Both 'message' and 'reason' are missing
                        reason_dict[REASON_KEY] = 'Exit code {code}'.format(
                            code=exit_code
                        )

                    return reason_dict
            except KeyError:
                continue

        # Failing that, return the 'message' or 'reason' value for the
        # pod
        for key in ['message', 'reason']:
            try:
                return {REASON_KEY: pod_status[key]}
            except KeyError:
                continue

        return {REASON_KEY: pod_status['phase']}
