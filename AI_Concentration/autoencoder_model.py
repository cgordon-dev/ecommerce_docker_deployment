import pandas as pd
import numpy as np
import sqlite3
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Input, Dense, Dropout
from tensorflow.keras.regularizers import l2
from tensorflow.keras.callbacks import EarlyStopping
import matplotlib.pyplot as plt
import argparse


def build_autoencoder(input_dim, encoding_dims, l2_reg=0.001, dropout_rate=0.0):
    """
    Builds an autoencoder with specified encoding dimensions, L2 regularization, and dropout.
    """
    input_layer = Input(shape=(input_dim,))
    encoded = input_layer

    # Encoder with L2 Regularization and Dropout
    for dim in encoding_dims:
        encoded = Dense(dim, activation="relu", kernel_regularizer=l2(l2_reg))(encoded)
        if dropout_rate > 0.0:
            encoded = Dropout(dropout_rate)(encoded)

    # Decoder with L2 Regularization and Dropout
    for dim in reversed(encoding_dims[:-1]):
        encoded = Dense(dim, activation="relu", kernel_regularizer=l2(l2_reg))(encoded)
        if dropout_rate > 0.0:
            encoded = Dropout(dropout_rate)(encoded)

    decoded = Dense(input_dim, activation="sigmoid")(encoded)

    autoencoder = Model(inputs=input_layer, outputs=decoded)
    autoencoder.compile(optimizer='adam', loss='mse')
    return autoencoder


def load_and_preprocess_data(db_path):
    """
    Loads data from the SQLite database and preprocesses it.
    """
    conn = sqlite3.connect(db_path)
    data = pd.read_sql_query("SELECT * FROM account_stripemodel", conn)
    conn.close()

    # Preprocessing
    data = data.dropna()
    data = data.replace([np.inf, -np.inf], np.nan).dropna()
    data = data.drop(['id', 'card_id', 'customer_id', 'email', 'address_city', 
                      'address_country', 'name_on_card'], axis=1)

    label_encoder = LabelEncoder()
    for column in ['address_state']:
        data[column] = label_encoder.fit_transform(data[column])

    scaler = StandardScaler()
    data_scaled = scaler.fit_transform(data)

    train_data, test_data = train_test_split(data_scaled, test_size=0.2, random_state=42)
    return train_data, test_data, scaler


def evaluate_model_performance(reconstruction_errors, threshold):
    """
    Evaluate and print model performance based on reconstruction errors.
    """
    mean_error = np.mean(reconstruction_errors)
    median_error = np.median(reconstruction_errors)
    min_error = np.min(reconstruction_errors)
    max_error = np.max(reconstruction_errors)
    std_error = np.std(reconstruction_errors)

    anomalies = reconstruction_errors > threshold
    num_anomalies = np.sum(anomalies)
    total_samples = len(reconstruction_errors)

    print("\nModel Performance Metrics")
    print("=" * 40)
    print(f"Reconstruction Error Statistics:")
    print(f"- Mean Error: {mean_error:.4f}")
    print(f"- Median Error: {median_error:.4f}")
    print(f"- Min Error: {min_error:.4f}")
    print(f"- Max Error: {max_error:.4f}")
    print(f"- Std Deviation: {std_error:.4f}")
    print("\nAnomaly Detection at Threshold")
    print("-" * 40)
    print(f"- Threshold: {threshold:.4f}")
    print(f"- Number of Anomalies Detected: {num_anomalies}")
    print(f"- Proportion of Anomalies: {num_anomalies / total_samples:.2%}")

    print("\nTop 5 Anomalies (Highest Reconstruction Errors):")
    top_anomalies = np.argsort(reconstruction_errors)[-5:][::-1]
    for idx in top_anomalies:
        print(f"  Sample Index: {idx}, Reconstruction Error: {reconstruction_errors[idx]:.4f}")


def plot_reconstruction_errors(reconstruction_errors, threshold, save_path):
    """
    Plots the distribution of reconstruction errors with a threshold line.
    """
    plt.figure(figsize=(10, 6))
    plt.hist(reconstruction_errors, bins=50, color='blue', alpha=0.7)
    plt.axvline(x=threshold, color='red', linestyle='--', label=f"Threshold ({threshold:.4f})")
    plt.title("Reconstruction Error Distribution")
    plt.xlabel("Reconstruction Error")
    plt.ylabel("Frequency")
    plt.legend()
    plt.savefig(save_path)
    plt.close()


def detect_and_evaluate_fraud(csv_path, model, scaler, threshold):
    """
    Detect and evaluate fraud on a new CSV dataset using the trained model.
    """
    print("\nDetecting Fraud on New Dataset")
    print("=" * 40)

    # Load the CSV data
    data = pd.read_csv(csv_path)

    # Preprocessing
    data = data.dropna()
    data = data.replace([np.inf, -np.inf], np.nan).dropna()
    if {'id', 'card_id', 'customer_id', 'email', 'address_city', 'address_country', 'name_on_card'}.issubset(data.columns):
        data = data.drop(['id', 'card_id', 'customer_id', 'email', 'address_city',
                          'address_country', 'name_on_card'], axis=1)

    label_encoder = LabelEncoder()
    if 'address_state' in data.columns:
        data['address_state'] = label_encoder.fit_transform(data['address_state'])

    # Scale the data using the same scaler used during training
    data_scaled = scaler.transform(data)

    # Compute reconstruction errors
    reconstructions = model.predict(data_scaled)
    reconstruction_errors = np.mean(np.square(reconstructions - data_scaled), axis=1)

    # Detect anomalies based on the threshold
    anomalies = reconstruction_errors > threshold
    num_anomalies = np.sum(anomalies)
    total_samples = len(reconstruction_errors)

    # Print performance metrics
    print(f"Threshold: {threshold:.4f}")
    print(f"Number of Anomalies Detected: {num_anomalies}")
    print(f"Proportion of Anomalies: {num_anomalies / total_samples:.2%}")

    # Print details of top 5 anomalies
    print("\nTop 5 Anomalies in New Dataset (Highest Reconstruction Errors):")
    top_anomalies = np.argsort(reconstruction_errors)[-5:][::-1]
    for idx in top_anomalies:
        print(f"  Sample Index: {idx}, Reconstruction Error: {reconstruction_errors[idx]:.4f}")

    # Save reconstruction errors
    np.save("new_dataset_reconstruction_errors.npy", reconstruction_errors)

    # Visualize reconstruction error distribution
    plt.figure(figsize=(10, 6))
    plt.hist(reconstruction_errors, bins=50, color='blue', alpha=0.7)
    plt.axvline(x=threshold, color='red', linestyle='--', label=f"Threshold ({threshold:.4f})")
    plt.title("Reconstruction Error Distribution (New Dataset)")
    plt.xlabel("Reconstruction Error")
    plt.ylabel("Frequency")
    plt.legend()
    plt.savefig("new_dataset_reconstruction_error_distribution.png")
    plt.close()


def main(args):
    # Load and preprocess data
    train_data, test_data, scaler = load_and_preprocess_data(args.db_path)

    # Build the Autoencoder with Regularization
    input_dim = train_data.shape[1]
    autoencoder = build_autoencoder(
        input_dim=input_dim,
        encoding_dims=args.encoding_dims,
        l2_reg=args.l2_reg,
        dropout_rate=args.dropout_rate
    )
    autoencoder.summary()

    # Early Stopping Callback
    early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)

    # Train the Autoencoder
    history = autoencoder.fit(
        train_data, train_data,
        epochs=args.epochs,
        batch_size=args.batch_size,
        validation_split=0.2,
        shuffle=True,
        callbacks=[early_stopping]
    )

    # Reconstruction Errors
    reconstructions = autoencoder.predict(test_data)
    reconstruction_errors = np.mean(np.square(reconstructions - test_data), axis=1)

    # Determine Threshold (e.g., 95th percentile)
    threshold = np.percentile(reconstruction_errors, args.threshold_percentile)
    print(f"\nSelected Threshold (at {args.threshold_percentile}th percentile): {threshold:.4f}")

    # Evaluate model performance and print metrics
    evaluate_model_performance(reconstruction_errors, threshold)

    # Visualize Reconstruction Errors with Threshold
    plot_reconstruction_errors(
        reconstruction_errors, 
        threshold, 
        "reconstruction_error_distribution.png"
    )

    # Detect and evaluate fraud on new dataset
    detect_and_evaluate_fraud(
        csv_path='/home/ubuntu/ecommerce_docker_deployment/AI_Concentration/account_stripemodel_fraud_data.csv',
        model=autoencoder,
        scaler=scaler,
        threshold=threshold
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate Autoencoder Performance for Anomaly Detection")
    parser.add_argument('--db_path', type=str, default='/home/ubuntu/ecommerce_docker_deployment/backend/db.sqlite3',
                        help='Path to the SQLite database.')
    parser.add_argument('--encoding_dims', type=int, nargs='+', default=[16, 8, 4],
                        help='List of encoding layer dimensions.')
    parser.add_argument('--epochs', type=int, default=100,
                        help='Number of training epochs.')
    parser.add_argument('--batch_size', type=int, default=32,
                        help='Batch size for training.')
    parser.add_argument('--l2_reg', type=float, default=0.001,
                        help='L2 regularization factor.')
    parser.add_argument('--dropout_rate', type=float, default=0.2,
                        help='Dropout rate for regularization.')
    parser.add_argument('--threshold_percentile', type=float, default=95.0,
                        help='Percentile to use as the anomaly detection threshold.')

    args = parser.parse_args()
    main(args)



#print training data:

# Path to your SQLite database
db_path = '/home/ubuntu/ecommerce_docker_deployment/backend/db.sqlite3'

# Connect to the SQLite3 database
conn = sqlite3.connect(db_path)

# Fetch and print the data
query = "SELECT * FROM account_stripemodel"  # Adjust table name as needed
data = pd.read_sql_query(query, conn)

# Close the connection
conn.close()

# Display the first few rows
print(data.head())

# Optionally, display column names and the structure of the data
print("\nColumn Names:", data.columns)
print("\nData Info:")
print(data.info())

data.to_csv('training_data.csv', index=False)