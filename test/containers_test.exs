defmodule DockerApiContainerTest do
  use ExUnit.Case
  require Logger

  @host "#{Application.get_env(:docker_api, :uri)}"

  defp create_image do
    DockerApi.Image.create(@host, %{"fromImage" => "redis", "tag" => "alpine"})
  end

  defp create_container do
    DockerApi.Container.create(@host, %{"image" => "redis:alpine"})
  end

  defp start_container(cid) do
    DockerApi.Container.start(@host, cid)
  end

  def exec_container(cid) do
    payload = %{ "AttachStdin": false, "AttachStdout": true, "AttachStderr": true, "Tty": false, "Cmd": [ "echo", "test"] }
    DockerApi.Container.exec(@host, cid, payload)
  end

  defp wait_for_containers([]), do: {:ok, []}

  defp wait_for_containers(containers) do
    {:ok, body, _status} = DockerApi.Container.all(@host)
    running_ids = body
      |> Enum.map(&(Map.get(&1,"Id")))
    wait_for_containers(containers -- running_ids)
    {:ok, body}
  end

  setup_all do
    Logger.debug "Creating image"
    {:ok, _body} = create_image()
    Logger.debug "Creating containers"
    {:ok, %{"Id" => cid, "Warnings" => _warnings}, 201} = create_container()
    {:ok, %{"Id" => delete_cid, "Warnings" => _warnings}, 201} = create_container()
    Logger.debug "Starting container"
    {:ok, _body, 204} = start_container(cid)
    Logger.debug "Starting exec container"
    {:ok, %{"Id" => exec_cid}, 201 }  = exec_container(cid)
    {:ok, _} = wait_for_containers([cid])
    {:ok, [cid: cid, delete_cid: delete_cid, exec_cid: exec_cid]}
  end

  test "/containers" do
    {:ok, body, _code }  = DockerApi.Container.all(@host)
    assert is_list(body)
  end

  test "/containers with options" do
    {:ok, body, _code }  = DockerApi.Container.all(@host, %{all: 1, limit: 1, size: 1})
    assert is_list(body)
  end

  test "/containers/create" do
    payload  = %{
      "Image": "redis:alpine",
      "AttachStdout": true,
      "AttachStderr": true
    }

    {:ok, body, code } = DockerApi.Container.create(@host, payload)
    IO.inspect(body)
    assert code == 201
  end

  test "/containers/id delete", context do
    {:ok, _body, code }  = DockerApi.Container.delete(@host, context[:delete_cid], %{force: 1})
    assert code == 204
  end

  test "/exec/id/start", context do
    payload = %{"Detach": false, "Tty": false}
    {:ok, body}  = DockerApi.Container.exec_start(@host, context[:exec_cid], payload)
    assert is_list(body)
  end

  test "/containers/id", context do
    {:ok, _body, code }  = DockerApi.Container.find(@host, context[:cid])
    assert is_number(code)
  end

  test "/containers/id/top", context do
    { :ok, body, _code } = DockerApi.Container.top(@host, context[:cid])
    IO.inspect(body)
    assert is_map(body)
  end

  test "/containers/id/changes", context do
    { :ok, _body, code } = DockerApi.Container.changes(@host, context[:cid])
    assert code == 200
  end

  test "/containers/id/stop", context do
    {:ok, _body, code } = DockerApi.Container.stop(@host, context[:cid])
    assert code == 204
  end
end
