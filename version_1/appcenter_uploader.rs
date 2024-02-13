use reqwest::blocking::{Client, RequestBuilder};
use std::fs;
use std::path::Path;

pub struct AppCenterAPI {
    base_url: String,
    owner_name: String,
    app_name: String,
    api_token: String,
}

impl AppCenterAPI {
    pub fn new(owner_name: &str, app_name: &str, api_token: &str) -> Self {
        Self {
            base_url: String::from("https://api.appcenter.ms/v0.1/apps/"),
            owner_name: owner_name.to_string(),
            app_name: app_name.to_string(),
            api_token: api_token.to_string(),
        }
    }

    pub fn upload_release(&self) -> Result<(), reqwest::Error> {
        let url = format!(
            "{}{}/{}/uploads/releases",
            self.base_url, self.owner_name, self.app_name
        );
        let client = Client::new();
        let request = client.post(&url).header("X-API-Token", &self.api_token);
        let response = request.send()?;
        // Handle response accordingly
        Ok(())
    }
}

pub struct MetadataUploader {
    base_url: String,
    response: Response,
}

impl MetadataUploader {
    pub fn new(response: Response) -> Self {
        Self {
            base_url: String::from("https://file.appcenter.ms/upload/set_metadata/"),
            response,
        }
    }

    pub fn upload_metadata(
        &self,
        file_name: &str,
        content_type: &str,
    ) -> Result<(), reqwest::Error> {
        let file_size_bytes = fs::metadata(file_name)?.len();
        let metadata_url = format!("{}/{}", self.base_url, self.response.package_asset_id);
        let client = Client::new();
        let request = client.post(&metadata_url).json(&json!({
            "file_name": file_name,
            "file_size": file_size_bytes,
            "token": self.response.url_encoded_token,
            "content_type": content_type
        }));
        let response = request.send()?;
        // Handle response accordingly
        Ok(())
    }
}

// Define other structs and their methods similarly

fn main() {
    // Example usage
    let api = AppCenterAPI::new("Example-Org", "Example-App", "Example-Token");
    api.upload_release().unwrap();

    let response = Response {
        id: "{ID}".to_string(),
        package_asset_id: "{PACKAGE_ASSET_ID}".to_string(),
        upload_domain: "https://file.appcenter.ms".to_string(),
        token: "{TOKEN}".to_string(),
        url_encoded_token: "{URL_ENCODED_TOKEN}".to_string(),
    };
    let uploader = MetadataUploader::new(response);
    uploader.upload_metadata("ExampleApp.apk", "application/vnd.android.package-archive").unwrap();
}

