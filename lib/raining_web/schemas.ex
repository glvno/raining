defmodule RainingWeb.Schemas do
  alias OpenApiSpex.Schema

  # ============================================================================
  # Auth Schemas
  # ============================================================================

  defmodule User do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User",
      description: "A user of the app",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "User ID"},
        email: %Schema{type: :string, description: "Email address", format: :email},
        confirmed_at: %Schema{
          type: :string,
          description: "Confirmation timestamp",
          format: :"date-time"
        },
        authenticated_at: %Schema{
          type: :string,
          description: "Auth timestamp",
          format: :"date-time"
        }
      },
      required: [:email],
      example: %{
        "id" => 123,
        "email" => "joe@gmail.com",
        "confirmed_at" => "2017-09-12T12:34:55Z",
        "authenticated_at" => "2017-09-13T10:11:12Z"
      }
    })
  end

  defmodule UserRegistrationParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UserRegistrationParams",
      description: "Request schema for user registration",
      type: :object,
      properties: %{
        user: %Schema{
          type: :object,
          description: "User registration data",
          properties: %{
            email: %Schema{type: :string, description: "Email address", format: :email},
            password: %Schema{
              type: :string,
              description: "Password (optional for magic-link registration)",
              format: :password,
              minLength: 12,
              maxLength: 72
            }
          },
          required: [:email]
        }
      },
      required: [:user],
      example: %{
        "user" => %{
          "email" => "user@example.com",
          "password" => "securepassword123"
        }
      }
    })
  end

  defmodule LoginParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "LoginParams",
      description: "Request schema for user login",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email address", format: :email},
        password: %Schema{type: :string, description: "Password", format: :password}
      },
      required: [:email, :password],
      example: %{
        "email" => "user@example.com",
        "password" => "securepassword123"
      }
    })
  end

  defmodule AuthResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthResponse",
      description: "Response schema for successful authentication (login or registration)",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Bearer token for API authentication"},
        user: %Schema{
          type: :object,
          description: "Basic user information",
          properties: %{
            id: %Schema{type: :integer, description: "User ID"},
            email: %Schema{type: :string, description: "Email address", format: :email}
          }
        }
      },
      required: [:token, :user],
      example: %{
        "token" => "SFMyNTY.g2gDaAJhAW4IAMCoYgD...",
        "user" => %{
          "id" => 123,
          "email" => "user@example.com"
        }
      }
    })
  end

  defmodule ErrorResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "Generic error response",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"}
      },
      required: [:error],
      example: %{
        "error" => "invalid_credentials"
      }
    })
  end

  defmodule ValidationErrorResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ValidationErrorResponse",
      description: "Validation error response with field-specific errors",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :object,
          description: "Map of field names to error messages",
          additionalProperties: %Schema{
            type: :array,
            items: %Schema{type: :string}
          }
        }
      },
      required: [:errors],
      example: %{
        "errors" => %{
          "email" => ["has already been taken"],
          "password" => ["should be at least 12 character(s)"]
        }
      }
    })
  end

  defmodule UserResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UserResponse",
      description: "Response schema for single user",
      type: :object,
      properties: %{
        data: User
      },
      example: %{
        "data" => %{
          "id" => 123,
          "email" => "joe@gmail.com",
          "confirmed_at" => "2017-09-12T12:34:55Z",
          "authenticated_at" => "2017-09-13T10:11:12Z"
        }
      }
    })
  end

  defmodule DropletParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletParams",
      description: "Request schema for creating a droplet",
      type: :object,
      properties: %{
        content: %Schema{
          type: :string,
          description: "Text content of the droplet",
          minLength: 1,
          maxLength: 500
        },
        latitude: %Schema{
          type: :number,
          description: "Latitude coordinate",
          minimum: -90,
          maximum: 90,
          format: :float
        },
        longitude: %Schema{
          type: :number,
          description: "Longitude coordinate",
          minimum: -180,
          maximum: 180,
          format: :float
        }
      },
      required: [:content, :latitude, :longitude],
      example: %{
        "content" => "It's raining here!",
        "latitude" => 52.5,
        "longitude" => 13.4
      }
    })
  end

  defmodule Droplet do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Droplet",
      description: "A droplet (social post with geolocation)",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "Droplet ID"},
        content: %Schema{type: :string, description: "Text content"},
        latitude: %Schema{type: :number, description: "Latitude coordinate", format: :float},
        longitude: %Schema{type: :number, description: "Longitude coordinate", format: :float},
        user: User,
        inserted_at: %Schema{
          type: :string,
          description: "Creation timestamp",
          format: :"date-time"
        },
        updated_at: %Schema{
          type: :string,
          description: "Last update timestamp",
          format: :"date-time"
        }
      },
      required: [:id, :content, :latitude, :longitude, :user, :inserted_at, :updated_at],
      example: %{
        "id" => 1,
        "content" => "It's raining here!",
        "latitude" => 52.5,
        "longitude" => 13.4,
        "user" => %{
          "id" => 123,
          "email" => "joe@gmail.com"
        },
        "inserted_at" => "2024-01-15T12:34:55Z",
        "updated_at" => "2024-01-15T12:34:55Z"
      }
    })
  end

  defmodule DropletResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletResponse",
      description: "Response schema for single droplet",
      type: :object,
      properties: %{
        droplet: Droplet
      },
      example: %{
        "droplet" => %{
          "id" => 1,
          "content" => "It's raining here!",
          "latitude" => 52.5,
          "longitude" => 13.4,
          "user" => %{
            "id" => 123,
            "email" => "joe@gmail.com"
          },
          "inserted_at" => "2024-01-15T12:34:55Z",
          "updated_at" => "2024-01-15T12:34:55Z"
        }
      }
    })
  end

  defmodule DropletsResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DropletsResponse",
      description: "Response schema for droplet feed",
      type: :object,
      properties: %{
        droplets: %Schema{
          type: :array,
          items: Droplet,
          description: "Array of droplets in the feed"
        },
        count: %Schema{type: :integer, description: "Number of droplets in the feed"},
        time_window_hours: %Schema{
          type: :integer,
          description: "Time window in hours used for the feed"
        },
        message: %Schema{type: :string, description: "Optional message (e.g., 'Not raining')"},
        rain_zone: %Schema{
          type: :object,
          nullable: true,
          description: "GeoJSON Polygon representing the rain zone area",
          example: %{
            "type" => "Polygon",
            "coordinates" => [
              [
                [-97.2, 39.7],
                [-97.0, 39.7],
                [-97.0, 39.8],
                [-97.2, 39.8],
                [-97.2, 39.7]
              ]
            ]
          }
        }
      },
      required: [:droplets, :count],
      example: %{
        "droplets" => [
          %{
            "id" => 1,
            "content" => "It's raining here!",
            "latitude" => 52.5,
            "longitude" => 13.4,
            "user" => %{
              "id" => 123,
              "email" => "joe@gmail.com"
            },
            "inserted_at" => "2024-01-15T12:34:55Z",
            "updated_at" => "2024-01-15T12:34:55Z"
          }
        ],
        "count" => 1,
        "time_window_hours" => 2,
        "rain_zone" => %{
          "type" => "Polygon",
          "coordinates" => [
            [
              [-97.2, 39.7],
              [-97.0, 39.7],
              [-97.0, 39.8],
              [-97.2, 39.8],
              [-97.2, 39.7]
            ]
          ]
        }
      }
    })
  end

  defmodule GlobalFeedResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GlobalFeedResponse",
      description: "Response schema for global droplet feed with rain zones",
      type: :object,
      properties: %{
        droplets: %Schema{
          type: :array,
          items: Droplet,
          description: "Array of all droplets in the feed"
        },
        count: %Schema{type: :integer, description: "Number of droplets in the feed"},
        time_window_hours: %Schema{
          type: :integer,
          description: "Time window in hours used for the feed"
        },
        rain_zones: %Schema{
          type: :array,
          description: "Array of GeoJSON polygons representing active rain zones",
          items: %Schema{
            type: :object,
            description: "GeoJSON Polygon"
          }
        }
      },
      required: [:droplets, :count, :rain_zones],
      example: %{
        "droplets" => [
          %{
            "id" => 1,
            "content" => "It's raining here!",
            "latitude" => 52.5,
            "longitude" => 13.4,
            "user" => %{"id" => 123, "email" => "joe@gmail.com"},
            "inserted_at" => "2024-01-15T12:34:55Z",
            "updated_at" => "2024-01-15T12:34:55Z"
          }
        ],
        "count" => 1,
        "time_window_hours" => 2,
        "rain_zones" => [
          %{
            "type" => "Polygon",
            "coordinates" => [[[-97.2, 39.7], [-97.0, 39.7], [-97.0, 39.8], [-97.2, 39.8], [-97.2, 39.7]]]
          }
        ]
      }
    })
  end

  # ============================================================================
  # Weather Schemas
  # ============================================================================

  defmodule WeatherCheckResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WeatherCheckResponse",
      description: "Response schema for weather rain check",
      type: :object,
      properties: %{
        is_raining: %Schema{type: :boolean, description: "Whether it is currently raining"},
        rounded_latitude: %Schema{
          type: :number,
          format: :float,
          description: "Latitude rounded to weather grid precision"
        },
        rounded_longitude: %Schema{
          type: :number,
          format: :float,
          description: "Longitude rounded to weather grid precision"
        },
        original_latitude: %Schema{
          type: :number,
          format: :float,
          description: "Original latitude provided"
        },
        original_longitude: %Schema{
          type: :number,
          format: :float,
          description: "Original longitude provided"
        }
      },
      required: [:is_raining, :rounded_latitude, :rounded_longitude, :original_latitude, :original_longitude],
      example: %{
        "is_raining" => true,
        "rounded_latitude" => 52.5,
        "rounded_longitude" => 13.4,
        "original_latitude" => 52.527,
        "original_longitude" => 13.416
      }
    })
  end
end
