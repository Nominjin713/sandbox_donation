import json
from datetime import timedelta
from django.test import TestCase
from django.core.cache import cache
from django.utils import timezone
from .models import AuthToken, User


class AuthenticationTests(TestCase):
    def setUp(self):
        cache.clear()
        self.data = {'name': 'Болд', 'email': 'BOLD@example.com', 'password': 'Strong!Pass483'}

    def post(self, route, data):
        return self.client.post(route, json.dumps(data), content_type='application/json')

    def test_authentication_lifecycle(self):
        result = self.post('/auth/register', self.data)
        self.assertEqual(result.status_code, 201)
        body = result.json()
        self.assertEqual(body['user']['email'], 'bold@example.com')
        self.assertNotIn('password', body['user'])
        self.assertTrue(User.objects.get().check_password(self.data['password']))
        self.assertEqual(self.post('/auth/register', self.data).status_code, 409)
        self.assertEqual(self.post('/auth/login', {**self.data, 'password': 'WrongPass483'}).status_code, 401)
        self.assertEqual(self.post('/auth/login', self.data).status_code, 200)
        self.assertEqual(self.client.get('/auth/me').status_code, 401)
        headers = {'HTTP_AUTHORIZATION': 'Bearer ' + body['token']}
        self.assertEqual(self.client.get('/auth/me', **headers).status_code, 200)
        self.assertEqual(self.client.post('/auth/logout', **headers).status_code, 200)
        self.assertEqual(self.client.get('/auth/me', **headers).status_code, 401)

    def test_invalid_input_and_expired_token(self):
        self.assertEqual(self.post('/auth/register', {**self.data, 'password': 'short'}).status_code, 400)
        self.assertEqual(self.post('/auth/register', {**self.data, 'email': 'invalid'}).status_code, 400)
        self.assertEqual(self.post('/auth/register', {**self.data, 'name': ''}).status_code, 400)
        self.assertEqual(self.post('/auth/register', None).status_code, 400)
        body = self.post('/auth/register', self.data).json()
        AuthToken.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.client.get('/auth/me', HTTP_AUTHORIZATION='Bearer ' + body['token']).status_code, 401)

    def test_rate_limit(self):
        for _ in range(20):
            self.post('/auth/login', {})
        self.assertEqual(self.post('/auth/login', {}).status_code, 429)

    def test_cors(self):
        response = self.client.options('/auth/login', HTTP_ORIGIN='http://localhost:3000')
        self.assertEqual(response.status_code, 204)
        self.assertEqual(response['Access-Control-Allow-Origin'], 'http://localhost:3000')
