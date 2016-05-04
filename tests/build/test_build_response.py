"""
Copyright (c) 2016 Red Hat, Inc
All rights reserved.

This software may be modified and distributed under the terms
of the BSD license. See the LICENSE file for details.
"""
import json
from osbs.build.build_response import BuildResponse

class TestBuildResponse(object):
    def test_get_logs(self):
        msg = "This is an error message"
        error = json.dumps({
            'errorDetail': {
                'code': 1,
                'message': msg,
                'error': msg,
            },
        })
        build_response = BuildResponse({
            'metadata': {
                'annotations': {
                    'logs': error,
                },
            },
        })

        assert msg in build_response.get_logs()

    def test_get_koji_build_id(self):
        koji_build_id = '123'
        build_response = BuildResponse({
            'metadata': {
                'labels': {
                    'koji-build-id': koji_build_id,
                 },
            },
        })
        assert build_response.get_koji_build_id() == koji_build_id

