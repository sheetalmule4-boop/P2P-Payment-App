from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import sqlite3
import os
import json


app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

DB_PATH = os.path.join(os.path.dirname(__file__), 'instance', 'users.db')

@app.route('/search_users', methods=['GET'])
def search_users():
    query = request.args.get('query', '').strip().lower()

    results = User.query.filter(
        (User.username.ilike(f'%{query}%')) |
        ((User.first_name + ' ' + User.last_name).ilike(f'%{query}%'))
    ).limit(10).all()

    return jsonify([
        {
            'name': f'{user.first_name} {user.last_name}',
            'username': user.username
        } for user in results
    ])


class ExpirationMonth(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    value = db.Column(db.String(2), unique=True, nullable=False) 

class ExpirationYear(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    value = db.Column(db.String(4), unique=True, nullable=False) 



class States(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(50))
    middle_name = db.Column(db.String(50), nullable=True)
    last_name = db.Column(db.String(50))
    phone_number = db.Column(db.String(10))
    email_id = db.Column(db.String(100))
    password = db.Column(db.String(100))
    username = db.Column(db.String(50), unique=True)


class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False) 
    card_number = db.Column(db.String(20))
    name_on_card = db.Column(db.String(100))
    address = db.Column(db.String(255))
    city = db.Column(db.String(100))
    state = db.Column(db.String(100))
    zip_code = db.Column(db.String(20))
    expiry_month = db.Column(db.String(2))
    expiry_year = db.Column(db.String(4))
    cvv = db.Column(db.String(4))
    user = db.relationship('User', backref=db.backref('cards', lazy=True))

class Booking(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    date = db.Column(db.String(10), nullable=False)  # Format: YYYY-MM-DD
    time = db.Column(db.String(20), nullable=False)  # Format: 8:00am - 9:00am
    court = db.Column(db.String(50), nullable=False)
    participants = db.Column(db.Text)
    amount_paid = db.Column(db.Text)
    card_used = db.Column(db.Text)
    user = db.relationship('User', backref=db.backref('bookings', lazy=True))


@app.route('/add_booking', methods=['POST'])
def add_booking():
    data = request.json
    user_id = data.get('user_id')
    date = data.get('date')
    time = data.get('time')
    court = data.get('court')
    participants = data.get('participants', '[]')
    amount_paid = data.get('amount_paid', '{}')
    card_used = data.get('card_used', '{}')

    if not all([user_id, date, time, court]):
        return jsonify({'error': 'Missing fields'}), 400

    booking = Booking(
        user_id=user_id,
        date=date,
        time=time,
        court=court,
        participants=json.dumps(participants),
        amount_paid=json.dumps(amount_paid),
        card_used=json.dumps(card_used)
    )
    db.session.add(booking)
    db.session.commit()
    return jsonify({'message': 'Booking saved'}), 201

@app.route('/get_user_bookings/<int:user_id>', methods=['GET'])
def get_user_bookings(user_id):
    bookings = Booking.query.filter_by(user_id=user_id).all()
    if not bookings:
        return jsonify([])  
    return jsonify([
        {
            'date': b.date,
            'time': b.time,
            'court': b.court
        } for b in bookings
    ])

@app.route('/get_bookings_by_date', methods=['GET'])
def get_bookings_by_date():
    date = request.args.get('date')
    if not date:
        return jsonify({'error': 'Missing date'}), 400

    bookings = Booking.query.filter_by(date=date).all()
    return jsonify([
        {
            'user_id': b.user_id,
            'date': b.date,
            'time': b.time,
            'court': b.court,
            'participants': json.loads(b.participants or '[]'),
            'amount_paid': json.loads(b.amount_paid or '{}'),
            'card_used': json.loads(b.card_used or '{}')
        } for b in bookings
    ])



@app.route('/add_card', methods=['POST'])
def add_card():
    data = request.get_json()

    if not data or 'user_id' not in data:
        return jsonify({'error': 'Missing user_id'}), 400

    card = Card(
        user_id=data['user_id'],
        card_number=data['card_number'][-4:],
        expiry_month=data['expiry_month'],
        expiry_year=data['expiry_year'],
        name_on_card=data['name_on_card'],
        cvv=data['cvv'],
        address=data['address'],
        city=data['city'],
        state=data['state'],
        zip_code=data['zip'],
    )

    db.session.add(card)
    db.session.commit()

    return jsonify({'message': 'Card added successfully'}), 201

@app.route('/get_states', methods=['GET'])
def get_states():
    all_states = States.query.all()
    return jsonify([n.name for n in all_states])

@app.route('/get_expiration_months', methods=['GET'])
def get_expiration_months():
    months = ExpirationMonth.query.order_by(ExpirationMonth.value).all()
    return jsonify([m.value for m in months])

@app.route('/get_expiration_years', methods=['GET'])
def get_expiration_years():
    years = ExpirationYear.query.order_by(ExpirationYear.value).all()
    return jsonify([y.value for y in years])


@app.route('/add_user', methods=['POST'])
def add_user():
    data = request.json

    if not data:
        return jsonify({'error': 'No input provided'}), 400

    if User.query.filter_by(username=data['username']).first():
        return jsonify({'field': 'username', 'error': 'Username is taken'}), 409

    if User.query.filter_by(email_id=data['email_id']).first():
        return jsonify({'field': 'email_id', 'error': 'Email is taken'}), 409

    if User.query.filter_by(phone_number=data['phone_number']).first():
        return jsonify({'field': 'phone_number', 'error': 'Phone number is taken'}), 409

    user = User(
        first_name=data['first_name'],
        middle_name=data.get('middle_name', ''),
        last_name=data['last_name'],
        phone_number=data['phone_number'],
        email_id=data['email_id'],
        password=data['password'],
        username=data['username']
    )
    db.session.add(user)
    db.session.commit()

    return jsonify({'message': 'Login successful', 'user_id': user.id}), 201


@app.route('/login_user', methods=['POST'])
def login_user():
    data = request.get_json()
    user_input = data.get('user_input')
    password = data.get('password')

    if not user_input or not password:
        return jsonify({'error': 'Missing username/email or password'}), 400

    if '@' in user_input and '.' in user_input:
        user = User.query.filter_by(email_id=user_input).first()
        if not user:
            return jsonify({'error': 'Email not found'}), 401
        elif user.password != password:
            return jsonify({'error': 'Email does not match password'}), 401
    else:
        user = User.query.filter_by(username=user_input).first()
        if not user:
            return jsonify({'error': 'Username not found'}), 401
        elif user.password != password:
            return jsonify({'error': 'Username does not match password'}), 401

    return jsonify({'message': 'Login successful', 'user_id': user.id}), 200

@app.route('/user/<int:user_id>', methods=['GET'])
def get_user(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    return jsonify({
        'first_name': user.first_name,
        'last_name': user.last_name,
        'email_id': user.email_id,
        'username': user.username
    }), 200


@app.route('/get_user_cards/<int:user_id>', methods=['GET'])
def get_user_cards(user_id):
    cards = Card.query.filter_by(user_id=user_id).all()
    return jsonify([
        {
            'id': c.id,
            'card_number': c.card_number,
            'name_on_card': c.name_on_card,
            'expiry_month': c.expiry_month,
            'expiry_year': c.expiry_year
        } for c in cards
    ])

@app.route('/delete_card/<int:card_id>', methods=['DELETE'])
def delete_card(card_id):
    card = Card.query.get(card_id)
    if not card:
        return jsonify({'error': 'Card not found'}), 404

    db.session.delete(card)
    db.session.commit()
    return jsonify({'message': 'Card deleted'}), 200

@app.route('/validate_username/<string:username>', methods=['GET'])
def validate_username(username):
    exists = User.query.filter_by(username=username).first() is not None
    return jsonify({'exists': exists})

@app.route('/get_user_by_username/<string:username>', methods=['GET'])
def get_user_by_username(username):
    user = User.query.filter_by(username=username).first()
    if not user:
        return jsonify({'error': 'User not found'}), 404
    return jsonify({
        'first_name': user.first_name,
        'last_name': user.last_name,
        'username': user.username
    }), 200

@app.route('/cancel_booking', methods=['DELETE'])
def cancel_booking():
    date = request.args.get('date')
    time = request.args.get('time')
    court = request.args.get('court')

    if not all([date, time, court]):
        return jsonify({'error': 'Missing required parameters'}), 400

    booking = Booking.query.filter_by(date=date, time=time, court=court).first()
    if not booking:
        return jsonify({'error': 'Booking not found'}), 404

    db.session.delete(booking)
    db.session.commit()
    return jsonify({'message': 'Booking cancelled'}), 200


if __name__ == '__main__':
    with app.app_context():
        db.create_all()

        # Seed expiration months
        months = [f"{i:02}" for i in range(1, 13)]
        for m in months:
            if not ExpirationMonth.query.filter_by(value=m).first():
                db.session.add(ExpirationMonth(value=m))

        # Seed expiration years
        from datetime import datetime
        current_year = datetime.now().year
        years = [str(y) for y in range(current_year, current_year + 11)]
        for y in years:
            if not ExpirationYear.query.filter_by(value=y).first():
                db.session.add(ExpirationYear(value=y))

        # Seed states
        states = [
            "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
            "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho",
            "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana",
            "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota",
            "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada",
            "New Hampshire", "New Jersey", "New Mexico", "New York",
            "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
            "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota",
            "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington",
            "West Virginia", "Wisconsin", "Wyoming",
        ]
        for name in states:
            if not States.query.filter_by(name=name).first():
                db.session.add(States(name=name))

        db.session.commit()
        print("Expiration months, years, and states seeded successfully.")

    app.run(host='0.0.0.0', port=1601, debug=True)

 